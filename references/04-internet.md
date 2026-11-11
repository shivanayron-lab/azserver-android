# 4. Internet: túnel e endereço fixo

## Túnel (já vem ligado)

O serviço `05-tunnel` roda o `cloudflared` em modo **quick tunnel**: ele abre uma conexão de saída até a Cloudflare e recebe um endereço público `https://<palavras>.trycloudflare.com` que leva ao roteador. Não precisa de conta, IP fixo nem porta aberta no roteador, e funciona atrás de CGNAT (a internet de operadora que não deixa abrir porta).

Limites:
- O endereço **muda a cada reinício** do túnel (reboot, queda de rede longa).
- A Cloudflare diz que o quick tunnel é para testes, sem garantia. Na prática é estável, mas para negócio sério use um túnel com nome (abaixo).
- Endereço atual: `azs.sh status` ou `/opt/azs/state/tunnel_url`. O supervisor o lê no próprio cloudflared: `curl 127.0.0.1:$METRICS_PORT/quicktunnel`.

## Endereço fixo grátis (Cloudflare Worker)

Um **Worker** é um programinha que roda na rede da Cloudflare num endereço fixo `https://<nome>.<subdomínio>.workers.dev`. O daqui repassa cada requisição para o endereço atual do túnel. O aparelho avisa o Worker quando o túnel muda (`POST /__set` com a chave `x-push-key`), e o Worker guarda o endereço no KV (banco chave-valor da Cloudflare).

Criar (no PC, com Node.js):
```
cd scripts/worker
bash setup-worker.sh meu-servidor ../../push.key
```
1. Abre o navegador para login na Cloudflare (conta grátis; confirme o e-mail antes). Se a pessoa não conseguir gerar token, este login OAuth dispensa o token.
2. Na primeira vez a conta precisa de um subdomínio `workers.dev`: se o script avisar, escolha em dash.cloudflare.com > Workers & Pages e rode de novo.
3. Cria o KV, publica o Worker e grava o segredo `PUSH_KEY`.

No aparelho:
```
# copie push.key para /data/azs/rootfs/opt/azs/keys/push.key (chmod 600), depois:
azs.sh run "sed -i 's|^WORKER_URL=.*|WORKER_URL=https://meu-servidor.SUB.workers.dev|' /opt/azs/azs.conf"
azs.sh stop; azs.sh start
```
Em até 15 s o log mostra "endereço fixo ... agora aponta para ...".

Segurança: o Worker recusa aviso sem a chave (403) e só aceita endereço `*.trycloudflare.com` (400). Quem tiver a chave pode desviar o tráfego para outro túnel, então ela fica só no aparelho e com a pessoa.

Comportamento medido no caso real: durante um reboot, o endereço fixo fica fora uns 1,5 a 3 minutos (o tempo do aparelho ligar). Depois, 100% (60 de 60 requisições). Se um app ou o túnel cai, volta em menos de 30 s com o endereço novo.

Limites do plano grátis: 100 mil requisições por dia. As regras da Cloudflare restringem servir principalmente vídeo e arquivos grandes pelo plano grátis: para isso, mande o cliente direto ao endereço do túnel, ou use outro caminho.

### Por que não Gist, GitHub Pages ou "DNS dinâmico"

- **Gist ou arquivo público com o endereço:** funciona como reserva, mas o arquivo "raw" do GitHub atrasa minutos depois de mudar, e a API do GitHub limita consultas vindas da Cloudflare. No caso real isso deu 503 intermitente até o aparelho passar a avisar o Worker direto.
- **GitHub Pages:** só serve arquivos estáticos e não repassa requisições. Serve no máximo para uma página que redireciona o navegador, não para API ou webhooks.
- **DNS dinâmico + porta aberta:** não funciona atrás de CGNAT e expõe o aparelho direto.

## Túnel com nome (opcional, endereço "oficial")

Com um domínio próprio na Cloudflare (a partir de uns US$ 1 a 12 por ano), crie um tunnel nomeado no painel (Zero Trust > Networks > Tunnels), pegue o token e troque o `CMD` do `05-tunnel.conf` por:
```
CMD='exec cloudflared tunnel --no-autoupdate --metrics "127.0.0.1:$METRICS_PORT" run --token "$(cat /opt/azs/keys/tunnel.token)"'
```
Aponte o hostname público para `http://127.0.0.1:<ROUTER_PORT>`. O endereço passa a ser fixo e o Worker fica dispensável (deixe `WORKER_URL` vazio).
