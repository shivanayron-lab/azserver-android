# 3. Serviços, supervisor e boot

## Supervisor (`/opt/azs/supervisor.sh`)

Um laço a cada 15 s, com uma cópia só (`flock`):
1. Para cada `/opt/azs/services/*.conf`, em ordem de nome: se não está saudável e já passou a carência (`GRACE`), para o grupo de processos e inicia de novo.
2. Lê o endereço atual do túnel e, se mudou, avisa o Worker (ver 04).
3. Uma vez por dia, roda o backup (ver 05). Se falhar, tenta de novo em 1 hora.

Cada serviço roda com `setsid` (grupo de processos próprio, fora da sessão do `su`) e log em `/opt/azs/log/<NAME>.log`. Ao iniciar, o supervisor apaga os `.pid` antigos: depois de um reboot eles apontariam para processos alheios.

## Arquivo de serviço

`/opt/azs/services/30-meuapp.conf` (sintaxe de shell; as variáveis de `azs.conf` estão disponíveis):

```
NAME=meuapp
DIR=/opt/meuapp
CMD='exec node server.js'            # roda com bash -c; use exec para o pid ser o do app
RUNAS=meuapp                          # opcional; o usuário precisa estar no grupo aid_inet
CHECK_URL=http://127.0.0.1:3000/      # saudável = respondeu HTTP (qualquer código)
# CHECK_CMD='mysqladmin ping'         # ou: saudável = comando saiu com 0
GRACE=60                              # segundos de carência depois de iniciar
```

Prefixos de número definem a ordem (banco `10-`, app `20-`). Para o app mudar de porta ou caminho, crie a rota:

`/opt/azs/routes/meuapp.caddy`
```
redir /meuapp /meuapp/ 308
handle_path /meuapp/* {
	reverse_proxy 127.0.0.1:3000
}
```
Depois: `azs.sh run 'pkill caddy'` (o supervisor sobe o roteador de novo com a rota nova). `handle_path` tira o prefixo `/meuapp` antes de repassar. Se o app gera links absolutos (`/assets/...`), ele precisa saber do prefixo (variável de "base path" do app) ou de um ajuste como o `patch-manager.sh` da Evolution.

Comandos: `azs.sh status`, `azs.sh run 'tail -50 /opt/azs/log/meuapp.log'`.

## Boot

`azs.sh install-boot` escreve `99azs.sh` na pasta de boot do root:
- **Magisk:** `/data/adb/service.d/` (roda tarde no boot, sem travar).
- **SuperSU:** `/data/adb/su/su.d/`, `/su/su.d/` ou `/system/su.d/`. **Roda cedo e o SuperSU espera os scripts terminarem antes de seguir**: por isso o script vai para segundo plano, espera `sys.boot_completed=1` e mais 30 s, e só então chama `azs.sh start`.

Log do boot: `/data/azs/boot.log`. Desfazer: `azs.sh remove-boot`.

## A CPU dorme

Com a tela apagada, o Android suspende a CPU, e o servidor para de responder até alguém tocar no aparelho. `azs.sh start` grava `azs` em `/sys/power/wake_lock` (trava de CPU do kernel, a mesma que apps usam); `stop` solta em `/sys/power/wake_unlock`. Conferir: `cat /sys/power/wake_lock`. O consumo sobe um pouco, por isso o aparelho fica na tomada.

Processos root (uid 0) não sofrem o bloqueio de rede do Doze, que vale só para apps. No caso real, com tela apagada e Doze forçado (`dumpsys deviceidle force-idle`), o servidor seguiu respondendo.
