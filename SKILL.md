---
name: azserver-android
description: Transforma um celular ou tablet Android com root (Magisk ou SuperSU) num servidor Linux ligado 24 horas, com Ubuntu em chroot, serviços que sobem sozinhos no boot e se reerguem quando caem, acesso pela internet sem abrir porta (túnel Cloudflare), endereço fixo grátis (Cloudflare Worker) e backup automático criptografado para o PC. Inclui receita pronta da Evolution API (WhatsApp para automações e CRM) e um app de teste. Use sempre que a pessoa quiser usar um Android antigo como servidor, VPS caseira, hospedar API, bot, n8n, banco de dados, site ou Evolution API no celular, rodar Linux/Ubuntu/Debian num Android com root, expor um serviço do celular na internet, ter URL fixa para algo rodando no celular, ou fazer backup de um servidor no celular, mesmo sem dizer "servidor". Também para "old phone as server", "self-host on Android", "chroot Ubuntu Android", "cloudflared on Android". Não serve para aparelho sem root (sugira Termux, com limites) nem para otimizar o celular (use android-optimizer).
---

# AZserver Android: o seu Android com root vira servidor

Esta skill guarda o método que pôs a Evolution API (WhatsApp) para rodar 24 horas num Galaxy S7 com root, acessível pela internet num endereço fixo e com backup diário no PC. O caso real está em `references/caso-s7.md`. Responda no idioma da pessoa (pt-BR por padrão) e explique cada termo técnico em uma frase.

## Como fica

```
Internet -> https://<nome>.<conta>.workers.dev    (Worker: endereço fixo, grátis)
         -> https://<aleatório>.trycloudflare.com (túnel: muda a cada reinício; o aparelho avisa o Worker)
         -> Caddy 127.0.0.1:ROUTER_PORT           (roteador: /evo, /hello, /_backup ...)
         -> apps no Ubuntu em chroot              (supervisor reergue o que cair)
```

Tudo roda **dentro do chroot**: o Ubuntu já traz DNS e certificados, então o cloudflared funciona sem gambiarras do Android. No aparelho fica só `/data/azs/azs.sh` (monta, liga, desliga, instala no boot) e o Ubuntu em `/data/azs/rootfs`.

## Princípios

- **O aparelho é da pessoa.** Explique antes de mexer em boot, partição ou `/system`. Root já precisa existir: esta skill não faz root (para isso, a skill android-optimizer).
- **Nunca apague o rootfs com coisa montada.** `rootfs/dev` é o `/dev` do Android emprestado: `rm -rf` com ele montado apaga o sistema. Use sempre `azs.sh uninstall --sim`, que desmonta, confere e só então apaga.
- **Segredos ficam com a pessoa.** Chaves geradas no aparelho (`/opt/azs/keys`) ou no PC. Nunca coloque chave, token ou endereço de alguém em arquivo que vá ser compartilhado ou publicado.
- **Diga os limites com franqueza** (`references/08-limites.md`): energia e internet de casa, bateria na tomada, um aparelho só, RAM, upload. Para cliente pagante que exige disponibilidade, VPS.
- **Só afirme o que verificou.** "Instalou" não é "sobe no boot", que não é "responde pela internet com a tela apagada". Teste cada degrau (ver Fluxo).
- **Uso responsável.** WhatsApp não oficial (Evolution/Baileys) bane número que manda em massa ou para quem não pediu: avise e recomende número separado. Não ajude a montar spam, phishing ou proxy para burlar bloqueio.

## Fluxo de trabalho

1. **Entrevista** (sem tocar no aparelho): o que vai rodar, quanta gente vai usar, se tem PC com adb e Python, se aceita criar conta grátis na Cloudflare (para o endereço fixo).
2. **Diagnóstico** → `references/01-diagnostico.md` e `scripts/recon.sh`: root, arquitetura, RAM, espaço, SELinux, SysV IPC, pasta de boot.
3. **Instalar o Linux** → `references/02-linux-chroot.md`: `scripts/install.sh -s <serial>` baixa o Ubuntu base (confere SHA-256), envia, extrai e roda `setup-base.sh` (rede do Android, apt, Caddy, cloudflared, chaves).
4. **Ligar e manter vivo** → `references/03-servicos-e-boot.md`: `azs.sh start`, serviços em `/opt/azs/services/*.conf`, rotas em `/opt/azs/routes/*.caddy`, `azs.sh install-boot`.
5. **Internet e endereço fixo** → `references/04-internet.md`: túnel já vem ligado; `scripts/worker/setup-worker.sh` cria o Worker e a chave de aviso.
6. **Backup** → `references/05-backup.md`: diário, criptografado, baixado pelo PC (`scripts/pc/agendar-backup.ps1` no Windows, cron no Linux/macOS). Faça a pessoa guardar `backup.key` fora do PC.
7. **Apps** → receitas em `recipes/`: `hello` (teste da cadeia toda, 1 minuto) e `evolution` (`references/06-receita-evolution.md`).
8. **Provar** (nesta ordem, anotando cada resultado): `azs.sh status` → endereço fixo responde → derrubar um app e ver voltar → reiniciar o aparelho e ver voltar sozinho → tela apagada por alguns minutos ainda responde → baixar e **abrir** um backup no PC.
9. **Problemas** → `references/07-problemas.md` antes de investigar do zero.

## Regras que evitaram horas de retrabalho

- **Rede paranoica do Android:** só o grupo 3003 (`aid_inet`) abre sockets. Todo usuário de serviço entra nele (`usermod -aG aid_inet,aid_net_raw <user>`), e o apt usa sandbox root. Sintoma: "Permission denied" ou "Temporary failure resolving" só para usuários não-root.
- **Pastas criadas pelo `su` nascem 700:** `chmod 755` na base e no rootfs, senão nenhum usuário além do root carrega a libc.
- **SuperSU fecha a saída do `su` cedo:** escrever nela dá SIGPIPE (código 141) e o `su` mata os filhos ao sair. Rode comandos por arquivo e mande a saída para arquivo; processos longos com `setsid`. Com aspas aninhadas (`adb shell "su -c '...'"`) escapes como `\1` somem: mande um script.
- **A CPU dorme com a tela apagada:** `azs.sh start` segura `/sys/power/wake_lock` (nome `azs`); `stop` solta.
- **`pkill -f padrão` casa consigo mesmo:** use `[x]` no padrão (`'node dist/mai[n]'`).
- **Pid de antes do reboot aponta para outro processo:** o supervisor apaga os `.pid` ao iniciar.
- **Kernel sem SysV IPC** (comum em Android): PostgreSQL não roda; use MariaDB/MySQL ou SQLite.
- **`mysqld_safe` falha no chroot:** chame `mariadbd --user=mysql` direto.
- **Endereço novo do túnel:** não dependa de Gist/arquivo público para descobri-lo (o CDN do GitHub atrasa minutos e a API limita). O próprio aparelho lê o endereço no cloudflared (`/quicktunnel` na porta de métricas) e avisa o Worker.
- **Arquivos de chave só com LF:** um `\r` do Windows faz o openssl do aparelho e o do PC lerem senhas diferentes ("bad decrypt").
