# 1. Diagnóstico do aparelho

Rode `scripts/recon.sh -s <serial>` (serial em `adb devices -l`). Ele envia um script para o aparelho e mostra:

| Item | Por que importa | Se der ruim |
|---|---|---|
| Root (Magisk/SuperSU) | Chroot, montagens e boot precisam de root | Sem root: esta skill não serve. Termux roda parte das coisas, sem boot automático confiável |
| ABI | Escolhe o Ubuntu (`arm64-v8a` → arm64, `armeabi-v7a` → armhf) | x86 de emulador funciona só para teste |
| RAM | Ubuntu base ~50 MB, Caddy ~30 MB, cloudflared ~30 MB, MariaDB ~150 MB, Node ~200-400 MB | Com 2 GB ou menos, um app pesado por vez. Build de Node pede ~1,5 GB livres |
| `/data` livre | Ubuntu ~400 MB depois do apt; Evolution ~1,5 GB com `node_modules` | Limpe ou use outro aparelho |
| SELinux | Enforcing é normal e funciona. O chroot herda o contexto do `su` | Só importa ao escrever em pasta de app (ver 07) |
| SysV IPC | Sem ele, o PostgreSQL não inicia (`shmget` falha) | MariaDB/MySQL ou SQLite |
| Pasta de boot | Onde `azs.sh install-boot` põe o script | Magisk: `/data/adb/service.d`. SuperSU: `/data/adb/su/su.d`, `/su/su.d` ou `/system/su.d` |
| wake_lock | Mantém a CPU acordada com a tela apagada | Se não for gravável, deixe a tela ligada no brilho mínimo ou use um app com WakeLock |
| Porta 8080 | Padrão do roteador | Ocupada: mude `ROUTER_PORT` em `/opt/azs/azs.conf` |

## Antes de começar, combine com a pessoa

- Aparelho na tomada, de preferência com **limite de carga** (a bateria incha se ficar em 100% o tempo todo; ver 08).
- Wi-Fi estável, de preferência com IP reservado no roteador (só ajuda no acesso local).
- Bloqueio de tela simples ou nenhum: com bloqueio seguro, alguns Androids só terminam o boot de apps depois do primeiro desbloqueio. O boot do `azs` não depende disso, mas apps Android de apoio dependem.
- Desligar atualizações automáticas do sistema (uma OTA pode tirar o root).
