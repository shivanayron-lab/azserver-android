# 8. Limites (diga com franqueza)

Um Android com root faz o papel de uma VPS: Linux completo, ligado 24 horas, acessível pela internet com HTTPS, custo zero por mês. Mas:

| Limite | Efeito | O que ajuda |
|---|---|---|
| Energia e internet de casa | Caiu, sai do ar | Nobreak pequeno no roteador e no carregador |
| Bateria sempre na tomada | Pode inchar em meses | Limite de carga (kernels com `/sys/class/power_supply/battery/` de controle, ou apps de root como ACC). Olhe a traseira de tempos em tempos |
| Um aparelho só | Quebrou, parou | Backup diário aberto e testado; scripts para reinstalar em outro aparelho ou VPS |
| Quick tunnel sem garantia | A Cloudflare pode mudar as regras | Túnel com nome e domínio próprio (ver 04) |
| RAM (2 a 4 GB típicos) | Poucos apps pesados ao mesmo tempo | Um app Node, um banco e pouca coisa mais. Monitore com `free -m` |
| Upload da internet | Vídeo e arquivos grandes para muita gente não escalam | Use para APIs, bots, painéis e webhooks |
| Plano grátis do Worker | 100 mil requisições por dia; restrição a servir vídeo | Vídeo direto pelo túnel ou por outro serviço |
| Atualização do Android | Uma OTA pode tirar o root | Desligue atualizações automáticas |

**Quando migrar para VPS** (a partir de uns R$ 25 a 40 por mês, ou a camada grátis da Oracle): clientes pagando e exigindo disponibilidade, muitos números ou instâncias, ou tráfego pesado. Os mesmos scripts servem: numa VPS Ubuntu, rode o conteúdo de `/opt/azs` direto, sem chroot, e restaure o backup.
