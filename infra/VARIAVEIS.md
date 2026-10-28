# Variáveis do projeto VNES (fonte única de verdade)

Todos os arquivos de `infra/` e `docs/` usam estes valores. Se mudar algum, mude aqui primeiro.

## Empresa e domínio
| Item | Valor |
|---|---|
| Empresa | VNES (loja de cartuchos virtuais NES) |
| Domínio | `vnes.com.br` |
| Repositório | https://github.com/JhonPaulMR/vnes-crud (branch `cloud-openstack`) |

## Hyper-V (host Windows 11 Pro)
| Item | Valor |
|---|---|
| Switch interno | `VNES-NET` |
| NAT | `VNES-NAT`, prefixo `192.168.50.0/24` |
| IP do host Windows no switch | `192.168.50.1/24` (gateway das VMs) |

## Máquinas
| Host | IP | Nomes DNS | Recursos | SO |
|---|---|---|---|---|
| Windows (cliente) | 192.168.50.1 | — | — | Windows 11 |
| VM `vnes-infra` | 192.168.50.10 | `ns1.vnes.com.br`, `ca.vnes.com.br` | 2 vCPU, 1 GB RAM, 20 GB | Ubuntu Server 24.04 |
| VM `vnes-cloud` | 192.168.50.20 | `cloud.vnes.com.br` | 4 vCPU, 11 GB RAM (estática), 100 GB, nested virt | Ubuntu Server 24.04 + DevStack |
| Instância `vnes-web` | floating IP em `172.24.4.0/24` (anotar) + privado `10.10.10.x` | `www.vnes.com.br`, `vnes.com.br` | flavor `vnes.small` | Ubuntu 24.04 cloud image |
| Instância `vnes-db` | só privado `10.10.10.x` (sem floating IP) | `db.vnes.com.br` | flavor `vnes.small` | Ubuntu 24.04 cloud image |

Interface de rede das VMs Ubuntu no Hyper-V: `eth0`. DNS das VMs: `192.168.50.10`. Exceção: a própria `vnes-infra` usa `127.0.0.1` (o Bind local) e `1.1.1.1`; no instalador, antes de o Bind existir, use `1.1.1.1`. O Bind encaminha para os forwarders 1.1.1.1 / 8.8.8.8.

## Rotas e DNS no cliente
- Rota persistente no Windows e na `vnes-infra`: `172.24.4.0/24` via `192.168.50.20`.
- Windows resolve só `*.vnes.com.br` pelo Bind via regra NRPT (`.vnes.com.br` → `192.168.50.10`).

## CA (na `vnes-infra`, diretório `/opt/vnes-ca`)
| Arquivo | Caminho |
|---|---|
| CA raiz (pública) | `/opt/vnes-ca/certs/vnes-root-ca.crt` |
| Chave da CA raiz | `/opt/vnes-ca/private/vnes-root-ca.key` |
| Certificado curinga | `/opt/vnes-ca/certs/wildcard.vnes.com.br.crt` (SAN: `*.vnes.com.br`, `vnes.com.br`) |
| Cadeia completa | `/opt/vnes-ca/certs/wildcard.vnes.com.br.fullchain.crt` (curinga + raiz) |
| Chave do curinga | `/opt/vnes-ca/private/wildcard.vnes.com.br.key` |

Nos servidores que usam o certificado (Horizon na `vnes-cloud`, Apache na `vnes-web`): `/etc/ssl/vnes/vnes.fullchain.crt` e `/etc/ssl/vnes/vnes.key` (o `03-distribuir.sh` também copia `/etc/ssl/vnes/vnes-root-ca.crt`, usado nos testes com `curl`).

## OpenStack (DevStack)
| Item | Valor |
|---|---|
| Horizon | `https://cloud.vnes.com.br/dashboard` |
| Rede pública (DevStack padrão) | `public`, `172.24.4.0/24`, gateway `172.24.4.1` |
| Projeto | `vnes` |
| Usuário DevOps | `vnes-devops` (papel `member` no projeto `vnes`) |
| Rede do projeto | `vnes-net` / subnet `vnes-subnet` `10.10.10.0/24`, DNS `192.168.50.10` |
| Roteador | `vnes-router` (gateway `public`) |
| Grupos de segurança | `sg-web` (22, 80, 443 de qualquer lugar; ICMP); `sg-db` (3306 e 22 só a partir de `sg-web`; ICMP) |
| Keypair | `vnes-key` |
| Imagem | `ubuntu-24.04` (noble-server-cloudimg-amd64.img), pública |
| Flavor | `vnes.small` = 1 vCPU, 1024 MB, 10 GB |

## Aplicação
| Item | Valor |
|---|---|
| Banco | MariaDB na `vnes-db`, base `vnes_db`, usuário `vnes` @ `10.10.10.%` |
| Senha do banco | definida no momento do render dos cloud-init (nunca versionada) |
| DocumentRoot web | `/var/www/vnes` (clone da branch `cloud-openstack`), uploads em `/var/www/vnes/uploads` |
| Variáveis do app | `DB_HOST=db.vnes.com.br`, `DB_DATABASE=vnes_db`, `DB_USERNAME=vnes`, `DB_PASSWORD=...` (via `SetEnv` no Apache) |
