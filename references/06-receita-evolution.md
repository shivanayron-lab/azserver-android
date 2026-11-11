# 6. Receita: Evolution API (WhatsApp)

A [Evolution API](https://github.com/EvolutionAPI/evolution-api) liga números de WhatsApp a automações e CRMs (n8n, Typebot, Chatwoot, webhooks) por uma API HTTP. Ela usa o WhatsApp Web de forma **não oficial** (Baileys).

**Avise a pessoa antes:** use um número separado do principal. Envio em massa, para quem não pediu ou com conteúdo repetitivo bane o número. Para volume comercial grande, a API oficial da Meta (WhatsApp Cloud API) é o caminho seguro.

## Instalar

```
azs.sh run 'bash /opt/azs/recipes/evolution/setup.sh'      # 15 a 40 minutos
azs.sh run 'pkill caddy'                                   # carrega a rota /evo
azs.sh status
```
Versão: `EVO_VERSION=2.3.7` (padrão). O script:
- instala MariaDB e Node.js 22 (oficial, conferido por SHA-256);
- configura o MariaDB só em 127.0.0.1, com pouca memória e sem AIO nativo (o kernel Android não tem);
- cria o banco, o usuário, a senha (`/opt/evo/db.pass`) e a **chave global da API** (`/opt/evo/api.key`);
- clona a Evolution, escreve o `.env` (MySQL, porta 8081, sem Redis, pt-BR) e compila só com `tsup` (o `tsc` completo pede mais RAM do que um celular tem);
- instala os serviços `10-mariadb`, `20-evolution`, a rota `/evo` e o gancho de backup (`mysqldump` + `.env` + chaves).

Durante o `npm ci`, o Android pode matar outros apps por falta de memória (low-memory killer). Feche o que der e, se algum app de apoio cair, abra de novo depois.

## Usar

- API: `<endereço>/evo/` com o header `apikey: <conteúdo de /opt/evo/api.key>`.
- Painel (Manager): `<endereço>/evo/manager/`. No login, em **Server URL** coloque `<endereço>/evo` (sem barra no fim) e a chave global.
- Conectar um número: crie uma instância (tipo Baileys), toque em conectar e leia o QR no WhatsApp do celular do número (Aparelhos conectados > Conectar aparelho). A sessão fica no banco e sobrevive a reinícios.
- `SERVER_URL` (links de mídia e webhooks) usa `WORKER_URL/evo`. Sem Worker, usa o endereço do túnel, que muda a cada reinício.

## Detalhes que custaram tempo

- **PostgreSQL não sobe** sem SysV IPC: `DATABASE_PROVIDER=mysql`.
- **`mysqld_safe` não funciona no chroot:** o serviço chama `mariadbd --user=mysql` direto.
- **O usuário `mysql` precisa do grupo `aid_inet`**, senão o MariaDB não abre nem a porta local.
- **O Manager usa caminhos absolutos** (`/manager`, `/assets`). Atrás de `/evo` a tela fica em branco. O `patch-manager.sh` reescreve os caminhos para `/evo/...` (originais em `.orig`) e roda antes de cada início, porque um update da Evolution traz os arquivos originais de volta. Outro prefixo: `EVO_PREFIX=/whats`.
- O proxy repassa gzip: para testar com curl, use `curl --compressed`.

## Restaurar de um backup

1. Instale a base e esta receita no aparelho novo (ou VPS).
2. `azs.sh stop`; copie `evo/env` para `/opt/evo/app/.env`, e `evo/api.key` e `evo/db.pass` para `/opt/evo/`.
3. Suba só o banco (`azs.sh run 'setsid mariadbd --user=mysql &'`), rode `mysql < evolution.sql` e recrie a senha do usuário `evo` com a do `db.pass` se for outra máquina.
4. `azs.sh start`. As instâncias voltam conectadas, a menos que o WhatsApp tenha desconectado o aparelho (após muitos dias fora, leia o QR de novo).
