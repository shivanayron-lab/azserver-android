# Caso real: Galaxy S7 como servidor da Evolution API

Aparelho: Samsung Galaxy S7 (SM-G930F, "herolte"), Android 8.0, kernel 3.18, arm64, 3,6 GB de RAM, root com SuperSU 2.82 (modo systemless, scripts de boot em `/data/adb/su/su.d`), SELinux enforcing, sem SysV IPC.

Objetivo da pessoa: vender automações e ações de CRM pelo WhatsApp sem pagar VPS.

## Como chegou lá (em ordem)

1. **Ubuntu 24.04 em chroot.** O tar do Ubuntu base foi descompactado no PC porque o tar do Android não abriu o `.gz`. Depois do apt, os usuários `_apt` e `mysql` não tinham rede: era a rede paranoica (grupo 3003). Pastas criadas pelo `su` vieram 700 e só o root carregava a libc.
2. **Banco.** O PostgreSQL não iniciou (kernel sem SysV IPC). A troca para MariaDB 10.11 resolveu, com AIO nativo desligado e iniciado direto com `mariadbd` (o `mysqld_safe` falhou).
3. **Evolution 2.3.7.** `npm ci` foi tão pesado que o low-memory killer matou o app que mantinha o túnel. A compilação completa (`tsc`) não coube na RAM; `tsup` sozinho bastou.
4. **Processos sumindo.** Tudo iniciado por `su -c` morria quando a sessão acabava, e a saída do `su` dava SIGPIPE (141). Com `setsid` e saída para arquivo, resolveu.
5. **Supervisor duplicado.** O app que relançava o script de vigia criou 17 cópias. Com `flock` ficou uma só. Um `pkill -f` casava consigo mesmo, resolvido com o padrão `[x]`.
6. **Painel em branco** atrás de `/evo`: caminhos absolutos no Manager, resolvido com o `patch-manager.sh`.
7. **Endereço mudando a cada reboot.** Primeiro um Gist guardava o endereço; um Worker que lia o Gist deu 503 intermitente por minutos depois de cada troca (CDN do GitHub atrasado e API limitada). A solução final foi o aparelho ler o próprio endereço no cloudflared e avisar o Worker, que guarda no KV.
8. **Backup.** O primeiro backup criptografado não abria: chave com `\r\n` do Windows. Gravando as chaves só com LF, abriu, com as 37 tabelas e as sessões do WhatsApp.

## Validação desta skill no mesmo aparelho

Instalação nova e separada em `/data/azs`, em paralelo à produção (que rodava por um app próprio), só com os scripts desta skill:
- `install.sh` do zero: rootfs de 105 MB, apt, Caddy 2.6.2 e cloudflared instalados.
- Receita `hello` respondendo pelo endereço fixo de um Worker de teste; `/_backup` com 403 sem token ou com token errado; download pelo `baixar-backup.ps1` com SHA-256 conferido; backup aberto no PC.
- Boot pelo `su.d` do SuperSU: voltou sozinho em **85 s** depois do reboot, com o wake lock ativo.
- Tela apagada + Doze forçado por 5 minutos: 11 de 12 respostas. A única falha foi no mesmo instante na produção, uma oscilação de rede.
- App e túnel derrubados com `kill -9`: tudo voltou em **27 s**, com o endereço fixo apontando para o túnel novo.
- `uninstall --sim`: primeiro recusou apagar (faltava `awk` no Android, então não desmontou), como devia; corrigido para `cut`, desmontou e apagou, com o `/dev` do sistema intacto (234 itens antes e depois).

Falhas encontradas no teste e já corrigidas nos scripts: opção `persist_config` que o Caddy 2.6 não conhece; `python3-minimal` sem `http.server`; adb.exe sem entender `/tmp` do Git Bash; `python3` falso da Microsoft Store.

A receita da Evolution desta skill reproduz a instalação que roda nesse aparelho, adaptada ao supervisor genérico; a instalação dela dentro do `/data/azs` não foi refeita no teste (leva até 40 minutos e pressiona a RAM). Na primeira vez que for usada, confira o passo 8 do fluxo.
