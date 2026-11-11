# 5. Backup automático criptografado

## No aparelho

Uma vez por dia (`BACKUP_EVERY_MIN`, padrão 23 h) o supervisor roda `/opt/azs/backup.sh`:
1. Cada gancho `/opt/azs/backup.d/*.sh` copia ou exporta o que é dele para a pasta de trabalho `$W` (exemplo: `mysqldump`).
2. `azs.conf`, `services/` e `routes/` vão junto. As **chaves não vão** (`keys/`): ficam fora de propósito.
3. Tudo vira um `.tar.gz` criptografado com AES-256 (`openssl enc -aes-256-cbc -pbkdf2 -iter 200000`), com a chave `/opt/azs/keys/backup.key`.
4. Ficam as últimas `BACKUP_KEEP` (7) em `/opt/azs/backups/`, e a mais nova vai para `/opt/azs/export/` (`latest.enc` + `latest.json` com nome, data, tamanho e SHA-256).

O roteador serve `/opt/azs/export` em `<endereço>/_backup/`, **só com o header `X-Backup-Token`** (`/opt/azs/keys/backup.token`). Sem ele dá 403. Mesmo que o token vaze, o arquivo continua ilegível sem a `backup.key`.

Fazer agora: `azs.sh backup`. Log: `/opt/azs/log/backup.log`.

## Pegar as chaves (uma vez)

```
adb shell "su -c 'cp /data/azs/rootfs/opt/azs/keys/backup.key /data/azs/rootfs/opt/azs/keys/backup.token /data/local/tmp/ && chmod 644 /data/local/tmp/backup.*'"
adb pull /data/local/tmp/backup.key
adb pull /data/local/tmp/backup.token
adb shell "su -c 'rm /data/local/tmp/backup.*'"
```
**A pessoa deve guardar `backup.key` também fora do PC** (pendrive, gerenciador de senhas). Sem ela nenhum backup abre, e se o PC morrer junto com o aparelho, perde-se tudo.

## No PC

Windows (sem precisar de administrador):
```
powershell -ExecutionPolicy Bypass -File scripts\pc\agendar-backup.ps1 -Url https://<endereço fixo> -Token <conteúdo de backup.token> -Dir C:\backups\servidor
```
Cria a tarefa "AZS - Backup do servidor Android": todo dia às 18h e 5 minutos depois do logon; se o PC estiver desligado no horário, roda quando ligar. Baixa, confere o SHA-256, guarda as últimas 30 e registra em `backup.log`.

Linux/macOS: `scripts/pc/baixar-backup.sh <endereço> <token> <pasta>` no cron (`0 18 * * *`).

## Abrir e restaurar

```
mkdir restaurado
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass file:backup.key -in backup-AAAA-MM-DD_HHMM.tar.gz.enc | (cd restaurado && tar -xzf -)
```
Em outro aparelho ou numa VPS: instale a base e as mesmas receitas, copie `azs/` de volta para `/opt/azs/` e siga o "restaurar" de cada receita (Evolution: `mysql < evolution.sql` e copiar `evo/env` para `/opt/evo/app/.env`).

**Um backup só vale depois de aberto uma vez.** No caso real, o primeiro "funcionou" mas não abria: a chave tinha `\r\n` do Windows. Os scripts daqui gravam chaves só com LF.
