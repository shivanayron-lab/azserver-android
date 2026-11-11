# 2. Linux no aparelho (Ubuntu em chroot)

**Chroot** = rodar programas com outra pasta fingindo ser a raiz `/`. O kernel continua o do Android; o resto (libc, apt, programas) é do Ubuntu. Não é emulação: roda na velocidade nativa.

## Instalar

No PC (Git Bash no Windows, ou Linux/macOS), com o aparelho no USB e a depuração ligada:

```
bash scripts/install.sh -s <serial>                 # baixa Ubuntu 24.04 base e confere o SHA-256
bash scripts/install.sh -s <serial> -t arquivo.tar.gz   # usando um tar já baixado
bash scripts/install.sh -s <serial> --scripts-only  # só atualiza scripts (mantém azs.conf, chaves e serviços)
```

O que ele faz:
1. Confere o root e a ABI.
2. Baixa `ubuntu-base-<versão>-base-<arch>.tar.gz` de `cdimage.ubuntu.com` e confere com `SHA256SUMS`.
3. **Descompacta no PC** (o `tar` do Android, toybox, nem sempre lê `.gz`) e envia o `.tar`.
4. Extrai em `/data/azs/rootfs` e faz `chmod 755` em `/data/azs` e no rootfs.
5. Envia `azs.sh` (para `/data/azs/`) e `/opt/azs/*` + `recipes/` (para dentro do Ubuntu).
6. Roda `/opt/azs/setup-base.sh`: grupos de rede, apt, Caddy, cloudflared e chaves.

Outra pasta: `-b /data/outra` (e `AZS_BASE=/data/outra` ao chamar `azs.sh`).

## Comandos do dia a dia (no aparelho, como root)

```
adb -s <serial> shell
su
sh /data/azs/azs.sh status        # serviços, endereço, último backup
sh /data/azs/azs.sh shell         # entrar no Ubuntu
sh /data/azs/azs.sh run 'apt install -y htop'
sh /data/azs/azs.sh start | stop
sh /data/azs/azs.sh uninstall --sim   # apaga tudo com segurança
```

Pelo PC sem entrar no aparelho: `adb shell "su -c 'sh /data/azs/azs.sh status'"`. Se sair código 141 ou nada, é o SIGPIPE do SuperSU: mande a saída para um arquivo e leia depois (ver 07).

## O que o setup-base corrige

- **Rede paranoica:** o Android só deixa abrir socket quem está no grupo 3003. Cria `aid_inet` (3003) e `aid_net_raw` (3004), põe root e `_apt` neles, e faz o apt usar sandbox root. **Todo usuário novo de serviço precisa entrar no grupo** (`usermod -aG aid_inet,aid_net_raw <user>`).
- **DNS:** `/etc/resolv.conf` com 1.1.1.1 e 8.8.8.8 se estiver vazio.
- **Certificados:** `ca-certificates` do Ubuntu, o que dispensa o truque de `SSL_CERT_FILE` que programas Linux precisam fora do chroot.

## Montagens

`azs.sh` monta, a cada chamada, `proc`, `sys`, `/dev` (bind), `devpts` e `/dev/shm` (tmpfs de 64 MB) dentro do rootfs. O SuperSU pode dar a cada sessão `su` um "namespace de montagem" próprio: por isso monta de novo em toda chamada, e o supervisor herda as montagens da sessão que o iniciou.

**Perigo:** `rootfs/dev` é o `/dev` do Android. `rm -rf /data/azs` com ele montado apaga o sistema. Use `azs.sh uninstall --sim`: ele desmonta, confere que `rootfs/dev/null` sumiu e só então apaga.

## Outras distros

Funciona com Debian (`debootstrap` no PC ou rootfs de `images.linuxcontainers.org`). Ajuste `setup-base.sh` (Caddy vem do repositório oficial dele no Debian 12). Alpine é mais leve, mas troca apt por apk e glibc por musl: as receitas daqui assumem Ubuntu/Debian.
