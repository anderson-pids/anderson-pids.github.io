# anderson-pids.github.io

Blog pessoal publicado em **https://www.anderson-pids.com.br**.

- Gerador: [Hugo](https://gohugo.io) **0.167.0 extended**
- Tema: [PaperMod](https://github.com/adityatelange/hugo-PaperMod), como submódulo git em `themes/PaperMod`
- Hospedagem: GitHub Pages, com deploy automático pelo GitHub Actions a cada push na `main`

## Estrutura

```
config.toml               # configuração do site (título, menu, profile, ícones)
content/
  about.md                # página About
  post/                   # artigos (um .md por post)
  search.md, archives.md  # páginas de busca e arquivo (layouts do PaperMod)
assets/img/profile.jpg    # foto da página inicial (o Hugo redimensiona no build)
static/CNAME              # domínio customizado: www.anderson-pids.com.br
archetypes/default.md     # modelo usado ao criar um post novo
themes/PaperMod/          # tema (submódulo, não editar aqui)
.github/workflows/        # CI/CD (gh-pages.yml)
```

## Primeira vez (depois do clone)

O tema é um submódulo, então precisa ser baixado:

```bash
git clone git@github.com:anderson-pids/anderson-pids.github.io.git
cd anderson-pids.github.io
make init            # = git submodule update --init --recursive
```

Sem o `make init`, a pasta `themes/PaperMod` fica vazia: o build termina, mas com avisos `found no layout file` e páginas em branco.

## Rodar localmente

Há duas opções. As duas usam o **mesmo Hugo da CI (0.167.0)**, para o que você vê local ser o que vai ao ar.

**Opção 1: Docker (recomendado, não instala nada)**

```bash
make serve           # sobe em http://localhost:1313 com rascunhos visíveis
```

O servidor recarrega a página sozinho quando você salva um arquivo. Para parar, use `Ctrl+C`.

**Opção 2: Hugo instalado na máquina**

Baixe o `hugo_extended_0.167.0_linux-amd64.tar.gz` em
<https://github.com/gohugoio/hugo/releases/tag/v0.167.0>, extraia o binário `hugo` para algum diretório do `PATH` e rode:

```bash
hugo server --buildDrafts
```

## Escrever um post

```bash
make new-post name=eks-with-terraform
```

Isso cria `content/post/eks-with-terraform.md` a partir do `archetypes/default.md`, com `draft: true`:

```yaml
---
title: "Eks With Terraform"   # ajuste o título
date: 2026-09-30T03:56:44Z
author: Anderson Pimentel
description: ""               # resumo curto: aparece na lista e em buscadores
tags: []                      # ex.: ["kubernetes", "terraform"]
draft: true                   # troque para false para publicar
---
```

- **Rascunho** (`draft: true`): aparece no `make serve`, mas **não** vai para produção.
- **Publicar:** troque para `draft: false`.
- **Imagens do post:** coloque em `static/images/<post>/` e referencie como `![alt](/images/<post>/arquivo.png)`.
- **Opções do PaperMod por post:** `ShowToc: true` mostra o índice; `cover.image` define uma imagem de capa. Veja a [wiki do PaperMod](https://github.com/adityatelange/hugo-PaperMod/wiki/Features).

## Build de produção (opcional, para conferir)

```bash
make build           # gera ./public com --minify, igual à CI
```

A pasta `public/` está no `.gitignore` e nunca é commitada. Quem publica é a CI.

## Mandar para produção

O workflow `.github/workflows/gh-pages.yml` faz:

| Evento | O que acontece |
|---|---|
| Pull request | Só **build**. Se o site quebrar, a CI fica vermelha e nada é publicado. |
| Push/merge na `main` | Build **e deploy**: publica `public/` na branch `gh-pages`, que o GitHub Pages serve. |

**Fluxo recomendado a cada mudança:**

```bash
git checkout -b post/eks-with-terraform
# escreve, testa com make serve, troca draft para false
git add -A && git commit -m "Post: EKS with Terraform"
git push -u origin post/eks-with-terraform
gh pr create --fill          # a CI builda o site no PR
gh pr checks --watch         # espera ficar verde
gh pr merge --merge          # merge na main = deploy
```

O site atualiza em 1–2 minutos depois do merge. Acompanhe com `gh run list`.
Se o navegador mostrar a versão antiga, recarregue com `Ctrl+Shift+R` (cache).

Para mudanças pequenas (corrigir um erro de digitação), dá para fazer commit direto na `main`. O push já publica.

## Manutenção

**Atualizar o tema:**

```bash
git submodule update --remote themes/PaperMod
make serve                   # conferir se nada quebrou
git add themes/PaperMod && git commit -m "Update PaperMod"
```

**Atualizar o Hugo:** a versão aparece em **três lugares**, que precisam ficar iguais:
- `hugo-version` em `.github/workflows/gh-pages.yml`
- `HUGO_IMAGE` no `Makefile`
- `image` no `docker-compose.yml`

Depois de trocar, rode `make build` e confira os avisos antes de abrir o PR.

**Trocar a foto:** substitua `assets/img/profile.jpg` por uma imagem quadrada (≥ 300×300 px). Tamanho e texto alternativo ficam em `[params.profileMode]` no `config.toml`.

## Problemas comuns

| Sintoma | Causa / solução |
|---|---|
| `found no layout file` ou página em branco | Tema não baixado: rode `make init`. |
| Post não aparece em produção | Ainda está com `draft: true`, ou a `date` está no futuro. |
| Página 404 no domínio | Confira se `static/CNAME` existe e se o domínio em *Settings → Pages* é `www.anderson-pids.com.br`. |
| Aviso `deprecated` no build | Vem do tema ou do Hugo mais novo. Não quebra o build, mas vale atualizar o tema. |
