# StockChef

Controle de estoque e produção para pequenas produtoras de alimentos.

Projeto do **Hackathon IFES Campus Santa Teresa – Economia Local e Pequenos Negócios** (19/10/2026).

## O problema

A Larissa Toffoli produz caldas e preparos. A cada lote, ela precisa saber quanto de cada ingrediente saiu do estoque e quanto ainda sobrou.

O StockChef faz essa conta sozinho: ela registra "hoje produzi 3 kg de calda de morango" e o app desconta do estoque a quantidade proporcional de cada ingrediente da receita.

## Funcionalidades

- Cadastro de ingredientes com estoque atual (kg, g, L, ml, un)
- Cadastro de receitas com ingredientes, quantidades e rendimento
- Registro de produção com baixa automática e proporcional do estoque
- Histórico de produção separado por dia

## Equipe

| Pessoa | Papel |
|---|---|
| Alexandre | Repositório, base do app, tela de produção e integração |
| Fernanda | Cadastro de receitas |
| Gabi | Design e UI |
| Julia | Cadastro de ingredientes e estoque |
| Paulo | Representante e pitch |

## Como rodar

Pré-requisitos: Flutter 3.41 (Dart 3.11) e um destes:
- Android: emulador ou celular com depuração USB
- Windows: Visual Studio com "Desenvolvimento para desktop com C++"

```bash
git clone https://github.com/AlexandreVenturini/stockchef.git
cd stockchef
flutter pub get
flutter run
```

Para rodar no Windows: `flutter run -d windows`. Para rodar os testes: `flutter test`.

Para apagar os dados e recriar o banco (por exemplo, depois de uma mudança nas tabelas):
- Windows: feche o app e apague `.dart_tool/sqflite_common_ffi/databases/stockchef.db`
- Android: desinstale o app

## Estrutura

```
lib/
  main.dart            inicia o banco e abre o app
  app.dart             tema e navegação com 3 abas
  core/                código compartilhado (tema, banco, unidades, formatação)
  features/
    ingredients/       ingredientes e estoque
    recipes/           receitas
    production/        produção e histórico
test/                  testes unitários
```

Cada funcionalidade tem:
- **modelo**: a classe com os campos (`ingredient.dart`)
- **repository**: o único lugar com SQL (`ingredient_repository.dart`)
- **páginas**: as telas, que só conversam com o repository (`ingredients_page.dart`)

## Como contribuir

Ninguém faz commit direto na `main`. Cada pessoa trabalha numa branch própria e envia para a `main` por Pull Request (PR).

**1. Criar sua branch** (uma por funcionalidade, com o nome do que está sendo feito, sem nome de pessoa):

```bash
git switch main
git pull
git switch -c cadastro-ingredientes
```

**2. Trabalhar e fazer commits pequenos**, com mensagem em português dizendo o que foi feito:

```bash
git add .
git commit -m "Adiciona lista de ingredientes"
```

**3. Enviar a branch** (na primeira vez; depois basta `git push`):

```bash
git push -u origin cadastro-ingredientes
```

**4. Abrir o Pull Request** no GitHub, da sua branch para a `main`. Antes, confira se `flutter analyze` e `flutter test` passam. O Alexandre testa e faz o merge.

**5. Trazer as novidades da `main`** para a sua branch, quando outra pessoa tiver feito merge:

```bash
git pull origin main
```

Regras:
- Cada pessoa mexe na sua pasta dentro de `lib/features/`
- Mudanças em `lib/core/` (banco, unidades, tema): combinar antes com o Alexandre
- No merge do PR, usar **"Create a merge commit"**, nunca "Squash", para não juntar os commits de cada pessoa num só

## Unidades

No banco, toda quantidade é guardada na **unidade base** da sua família:

| Família | Unidades | Base |
|---|---|---|
| Peso | kg, g | g |
| Volume | L, ml | ml |
| Unidade | un | un |

Se a pessoa digita "1,5 kg", o banco grava `1500` e guarda `kg` só para mostrar na tela. Assim todas as contas acontecem na mesma unidade. Os campos de unidade só oferecem unidades da mesma família do ingrediente.

## Modelo de dados

| Tabela | Campos |
|---|---|
| `ingredients` | id, name, unit, stock, min_stock, price |
| `recipes` | id, name, yield_qty, yield_unit, output_ingredient_id |
| `recipe_items` | id, recipe_id, ingredient_id, quantity, unit |
| `productions` | id, recipe_id, recipe_name, date, quantity, unit, created_at |
| `production_items` | id, production_id, ingredient_id, ingredient_name, quantity, unit |

`min_stock`, `price` e `output_ingredient_id` são para funcionalidades extras e ainda não têm tela.

### Como funciona a baixa de estoque

```
fator   = quantidade produzida / rendimento da receita
consumo = quantidade do ingrediente na receita × fator
```

Exemplo: a receita rende 1 kg com 600 g de morango. Produzindo 2,5 kg, o fator é 2,5 e saem 1500 g de morango do estoque.

- Se faltar ingrediente, o app avisa e pede confirmação. Se confirmar, o estoque fica negativo e aparece em vermelho.
- Cada produção guarda o que consumiu, então o histórico não muda se a receita for editada depois.
- Excluir uma produção devolve os ingredientes ao estoque.

## Pacotes utilizados

| Pacote | Para quê |
|---|---|
| [sqflite](https://pub.dev/packages/sqflite) | Banco de dados SQLite no Android |
| [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) | O mesmo banco SQLite no Windows |
| [path](https://pub.dev/packages/path) | Montar o caminho do arquivo do banco |
| [intl](https://pub.dev/packages/intl) | Formatar datas e números no padrão brasileiro |
| flutter_localizations (Flutter SDK) | Textos padrão do Flutter, como o calendário, em português |
| [flutter_lints](https://pub.dev/packages/flutter_lints) | Regras de boas práticas na análise do código (desenvolvimento) |
