# AZserver Android

Skill do [Claude Code](https://claude.com/claude-code) que transforma um **celular ou tablet Android com root** num servidor Linux ligado 24 horas, acessível pela internet num endereço fixo e com backup automático no PC. Tudo grátis.

Nasceu de um Galaxy S7 antigo que passou a rodar a Evolution API (WhatsApp para automações e CRM) no lugar de uma VPS. O método, os problemas encontrados e os scripts foram generalizados e testados de novo no aparelho.

```
Internet -> https://<nome>.<conta>.workers.dev    endereço fixo (Cloudflare Worker, grátis)
         -> https://<aleatório>.trycloudflare.com túnel sem abrir porta (muda; o aparelho avisa o Worker)
         -> Caddy                                 roteador: /evo, /hello, /_backup ...
         -> apps no Ubuntu em chroot              supervisor reergue o que cair
```

## O que ela faz

- Confere o aparelho (root, arquitetura, RAM, SELinux, SysV IPC, pasta de boot, wake lock).
- Instala o Ubuntu 24.04 em chroot a partir do PC, com o download conferido por SHA-256, e corrige a "rede paranoica" do Android.
- Supervisor simples: cada app é um arquivo `.conf` e cada rota um arquivo `.caddy`. O que cair volta sozinho.
- Sobe sozinho no boot (Magisk `service.d` ou SuperSU `su.d`) e segura a CPU acordada com a tela apagada.
- Túnel Cloudflare sem conta e endereço fixo grátis com um Worker, avisado pelo próprio aparelho.
- Backup diário criptografado (AES-256), baixado pelo PC com uma tarefa agendada no Windows ou cron no Linux/macOS.
- Receitas: `hello` (teste da cadeia toda) e `evolution` (Evolution API + MariaDB + Node.js 22).
- Desinstalação segura, que nunca apaga o `/dev` do Android.

## Testado

Num Galaxy S7 (Android 8, SuperSU), instalação do zero com estes scripts:
- volta sozinho do reboot em 85 s;
- responde com a tela apagada e em Doze forçado;
- app e túnel derrubados voltam em 27 s, com o endereço fixo acompanhando;
- backup baixado e aberto no PC.

Detalhes em `references/caso-s7.md`.

## Instalação da skill

```
git clone https://github.com/shivanayron-lab/azserver-android ~/.claude/skills/azserver-android
```
No Windows: `git clone https://github.com/shivanayron-lab/azserver-android %USERPROFILE%\.claude\skills\azserver-android`

Depois, no Claude Code, peça algo como "quero usar meu celular antigo com root como servidor" ou use `/azserver-android`.

Precisa no PC: adb, Python 3 e curl (Windows: Git Bash). Para o endereço fixo: Node.js e uma conta grátis na Cloudflare.

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `SKILL.md` | Princípios, fluxo de trabalho e regras |
| `references/01-diagnostico.md` … `08-limites.md` | Uma referência por etapa |
| `references/07-problemas.md` | Sintoma → causa → solução |
| `references/caso-s7.md` | O caso real e o teste desta skill |
| `scripts/recon.sh` | Diagnóstico do aparelho por adb |
| `scripts/install.sh` | Instala ou atualiza tudo pelo PC |
| `scripts/device/azs.sh` | No aparelho: start, stop, status, shell, backup, install-boot, uninstall |
| `scripts/chroot/opt/azs/` | Supervisor, backup, Caddyfile, serviços base (roteador e túnel), setup |
| `scripts/worker/` | Worker do endereço fixo + `setup-worker.sh` |
| `scripts/pc/` | Download e agendamento do backup (Windows e Linux/macOS) |
| `recipes/hello`, `recipes/evolution` | Apps prontos |

## Aviso

Use num aparelho seu. Celular na tomada 24 horas pode inchar a bateria, e um servidor em casa cai junto com a energia e a internet. A Evolution API usa o WhatsApp de forma não oficial: envio em massa ou para quem não pediu bane o número.

## Licença

MIT. Veja [LICENSE](LICENSE).
