# homelab-k8s

Mini cluster Kubernetes de homelab, com GitOps e gerenciamento web via Rancher.

## Arquitetura

```
Seu PC                              AWS (t3a.medium, liga/desliga sob demanda)
┌─────────────────────────┐         ┌─────────────────────────┐
│ cluster kind             │         │ Rancher (Docker)         │
│  └─ Argo CD              │         │  └─ importa o cluster    │
│      sincroniza a partir │ agent   │     kind (conexão de     │
│      deste repo Git  ────┼────────>│     saída, sem expor     │
│                          │         │     sua rede)            │
└─────────────────────────┘         └─────────────────────────┘
         ▲
         │ git push
         │
   GitHub Actions (CI): valida YAML/kustomize/Terraform a cada push/PR
```

- **Cluster local**: [kind](https://kind.sigs.k8s.io/) — roda inteiro em containers Docker na sua máquina.
- **GitOps**: [Argo CD](https://argo-cd.readthedocs.io/), padrão "app of apps" — tudo que está em `clusters/homelab/apps/` é sincronizado automaticamente a partir deste repositório.
- **Gerenciamento web**: [Rancher](https://ranchermanager.docs.rancher.com/), rodando numa instância EC2 que você liga só quando for usar (ver custos abaixo).
- **CI**: GitHub Actions valida manifests, kustomize builds e Terraform a cada push/PR — não faz deploy (quem aplica no cluster é o Argo CD, de dentro de casa).

## Estrutura do repositório

```
kind/cluster.yaml              # Definição do cluster kind (1 control-plane + 1 worker)
clusters/homelab/
  bootstrap/                   # Instalação do Argo CD (única coisa aplicada à mão)
  apps/                        # Um arquivo = uma Application do Argo CD (app of apps)
  root-app.yaml                # A "root app" que aponta pra clusters/homelab/apps/
apps/
  base/hello-homelab/          # App de exemplo (nginx) só com manifests deste repo
  overlays/homelab/            # Overlay do cluster "homelab" sobre a base acima
infra-aws/                     # Terraform da instância EC2 que roda o Rancher
scripts/                       # bootstrap.sh, cluster-up.sh, cluster-down.sh, update-allowed-ip.sh
.github/workflows/ci.yml       # Validação (yamllint + kustomize + kubeconform + terraform)
```

## Primeira vez (do zero)

```bash
# 1. Cluster local + Argo CD
scripts/bootstrap.sh

# 2. Rancher na AWS (precisa de `aws sso login` ou `aws configure` antes)
cd infra-aws
terraform init
terraform apply
cd ..
```

Depois do `terraform apply`, use `scripts/cluster-up.sh` pra ligar e descobrir a URL (o IP muda a cada boot, ver seção de custos).

Pra importar o cluster kind no Rancher: na UI do Rancher (`Cluster Management → Import Existing`), copie o comando `kubectl apply -f ...` gerado e rode apontando pro seu `kubeconfig` do kind.

## Uso do dia a dia

```bash
scripts/cluster-up.sh         # liga a instância do Rancher, mostra a URL e o comando SSH
# ... usa o Rancher ...
scripts/cluster-down.sh       # desliga (só o disco continua sendo cobrado)
```

O cluster kind local não precisa ser recriado — ele já roda local e continua no ar entre sessões, só a instância do Rancher na AWS é que liga/desliga sob demanda.

Se seu IP de casa mudar e o Rancher parar de responder:

```bash
scripts/update-allowed-ip.sh
```

## Custos (AWS)

| Item | Regra | Estimativa |
|---|---|---|
| Disco EBS (gp3, 40GB) | cobrado 24/7, ligado ou não | ~R$16/mês fixo |
| Compute (t3a.medium) | só enquanto ligado | $0,0376/h |
| IP público | só enquanto ligado | $0,005/h |

Com uso moderado (~25h/mês), fica em torno de **R$20-25/mês**. Sem Elastic IP de propósito — reservar um IP fixo cobraria 24/7 mesmo parado, anulando a economia.

Hostname do Rancher: `https://<ip-público-atual>.sslip.io` — muda a cada restart porque não há IP fixo. Certificado é autoassinado (aceite o aviso do navegador uma vez; ele é reaproveitado entre reinícios porque fica salvo em `/var/lib/rancher` no disco).

## Adicionando um novo app

1. Crie `apps/base/<nome>/` com os manifests (ou um `Application` apontando pra um chart Helm, como em `clusters/homelab/apps/podinfo.yaml`).
2. Adicione um arquivo `clusters/homelab/apps/<nome>.yaml` com a `Application` do Argo CD.
3. Liste esse arquivo em `clusters/homelab/apps/kustomization.yaml`.
4. `git push` — o Argo CD sincroniza automaticamente (sem precisar de `kubectl apply`).

## O que o CI valida (não faz deploy)

- `yamllint` em todo o repositório.
- `kubectl kustomize` + `kubeconform` nos três diretórios kustomize-áveis (bootstrap, apps, overlay do hello-homelab).
- `terraform fmt -check` e `terraform validate` em `infra-aws/`.
