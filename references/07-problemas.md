# 7. Sintomas e soluções

| Sintoma | Causa | Solução |
|---|---|---|
| `adb shell "su -c ..."` não mostra nada ou sai com 141 | SuperSU fecha a saída do `su` cedo (SIGPIPE) | Mande a saída para arquivo e leia depois; scripts daqui já fazem isso |
| Processo some quando o comando `su` termina | A sessão do SuperSU mata os filhos | Inicie com `setsid` (o `azs.sh start` faz isso) |
| `sed 's/x\(..\)/\1/'` vira lixo pelo adb | Escapes comidos em aspas aninhadas (Git Bash → adb → su → sh) | Escreva um script num arquivo, envie e rode |
| Caminho `/data/...` vira `C:/Program Files/Git/data/...` | Git Bash converte caminhos | `export MSYS_NO_PATHCONV=1` |
| `adb push /tmp/x` falha no Windows | adb.exe não entende caminho do Git Bash | `cygpath -w` (o `install.sh` faz isso) |
| "Python não foi encontrado" no Windows | `python3` é atalho da Microsoft Store | O `install.sh` testa `python3`, `python` e `py`. Desligue o alias em Configurações > Aplicativos > Aliases |
| `apt update`: "Temporary failure resolving" ou permission denied | Rede paranoica: `_apt` fora do grupo 3003 | `setup-base.sh` (grupos + sandbox root) |
| Serviço de usuário não-root sem rede | Usuário fora do `aid_inet` | `usermod -aG aid_inet,aid_net_raw <user>` |
| "error while loading shared libraries" para não-root | Pastas 700 criadas pelo `su` | `chmod 755 /data/azs /data/azs/rootfs` |
| PostgreSQL: "could not create shared memory segment" | Kernel sem SysV IPC | MariaDB ou SQLite |
| MariaDB não sobe com `mysqld_safe`/`service` | Sem init no chroot | `mariadbd --user=mysql` direto (serviço) |
| Caddy: "unrecognized global option" | Versão do Ubuntu (2.6) é antiga | Tire a opção; não use as opções novas no Caddyfile |
| `python3 -m http.server`: "No module named http" | `python3-minimal` vem sem a biblioteca padrão completa | Instale `python3` |
| `pkill -f 'node app'` mata o próprio pkill/shell | O padrão casa com a linha do comando | Use `'node ap[p]'` |
| Servidor só responde com a tela ligada | CPU suspensa | Wake lock (`azs.sh start` faz). Confira `cat /sys/power/wake_lock` |
| Endereço fixo dá 503 por alguns minutos depois do reboot | Aparelho ainda ligando, ou túnel novo ainda não avisado | Normal até ~3 min. Se passar disso: `azs.sh status`, `supervisor.log` ("endereço fixo agora aponta") |
| Endereço fixo 503 intermitente com o túnel direto ok | Worker lendo endereço velho de um cache (Gist/CDN) | Use o aviso direto do aparelho (`/__set`), não um arquivo público |
| Tudo 503 pelo endereço fixo, com aparelho, apps e cloudflared "conectado" e `/ready` 200 | A Cloudflare apagou o endereço do quick tunnel (`nslookup <endereço>` = domínio inexistente) | O supervisor reinicia o túnel sozinho após 3 falhas do endereço público (~6 min). Na mão: `azs.sh stop; azs.sh start` |
| `/__set` responde 503 "kv: ... limit exceeded" (antes: erro 1101) e o endereço fixo fica no túnel velho | Cota grátis do KV (1.000 gravações/dia, **conta inteira**) gasta por outro Worker | Passe o Worker que grava muito para o D1. A cota zera à meia-noite UTC (ver 04) |
| Evolution reinicia sozinha de madrugada; log com `JavaScript heap out of memory` e milhares de `Browser:` por minuto | Reconexão ao WhatsApp sem espera durante queda de internet | `patch-reconnect.js` da receita (ver 06) |
| Painel web em branco atrás de `/prefixo` | App com caminhos absolutos | "Base path" do app, ou reescrever como o `patch-manager.sh` |
| Backup "bad decrypt" | Chave com `\r\n` (Windows) lida diferente em cada lado | Chave só com LF: `sed -i 's/\r$//' backup.key` nos dois lados e gere de novo |
| App Android de apoio lê "Permission denied" em arquivo criado pelo root | Rótulo SELinux sem as categorias do app (`s0:cNNN,cNNN`) | `chcon "$(stat -c %C pasta)" arquivo` |
| `uninstall` diz que ainda há algo montado | Montagem viva em outro namespace | Reinicie o aparelho e rode de novo. **Nunca** `rm -rf` na mão |
| Low-memory killer mata apps durante build | RAM curta | Feche apps; compile com `NODE_OPTIONS=--max-old-space-size=1536`; ou compile no PC e envie |
