# Gerenciador de Tarefas Escolares: Banco de Dados

Banco de dados do projeto, em **PostgreSQL 16**. Este repositório tem o script de criação das tabelas e um `docker-compose.yml` que sobe o banco pronto com um único comando.

## Subindo o banco na sua máquina (recomendado)

Pré-requisito: [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e aberto.

```bash
git clone https://github.com/Gerenciador-de-Tarefas-Escolares/Gerenciador-tarefa-banco
cd Gerenciador-tarefa-banco

cp .env.example .env        # no Windows (CMD): copy .env.example .env
docker compose up -d
```

Pronto: o PostgreSQL está rodando em `localhost:5432` com todas as tabelas criadas. Não precisa instalar nem configurar o Postgres.

Para conferir:

```bash
docker compose exec banco psql -U gerenciador -d gerenciador_tarefas -c "\dt"
```

(se você mudou `DB_USUARIO` ou `DB_NOME` no `.env`, use os seus valores)

### Comandos do dia a dia

| O que fazer | Comando |
|---|---|
| Ligar o banco | `docker compose up -d` |
| Desligar (mantém os dados) | `docker compose stop` |
| Ver os logs | `docker compose logs -f banco` |
| Entrar no banco | `docker compose exec banco psql -U gerenciador -d gerenciador_tarefas` |
| **Zerar tudo e recriar as tabelas** | `docker compose down -v && docker compose up -d` |

> **Importante:** o script `01_criar_tabelas.sql` só roda quando o banco está **vazio** (na primeira vez). Se o script for atualizado, rode `docker compose down -v && docker compose up -d` para recriar. **Isso apaga os dados locais.**

### Configuração (`.env`)

O arquivo `.env` guarda as credenciais e **não vai para o GitHub** (está no `.gitignore`). O modelo é o `.env.example`:

| Variável | Para que serve | Padrão |
|---|---|---|
| `DB_NOME` | nome do banco | `gerenciador_tarefas` |
| `DB_USUARIO` | usuário | `gerenciador` |
| `DB_SENHA` | senha (obrigatória) | `troque_esta_senha` |
| `DB_PORTA` | porta na sua máquina | `5432` |

Se a porta 5432 já estiver ocupada (por exemplo, por outro Postgres instalado), mude `DB_PORTA` para `5433`, e use `5433` também na URL de conexão do back-end.

## Conectando o back-end (Spring Boot)

No `application.properties`, **sem escrever a senha no arquivo**:

```properties
spring.datasource.url=jdbc:postgresql://localhost:${DB_PORTA:5432}/${DB_NOME:gerenciador_tarefas}
spring.datasource.username=${DB_USUARIO}
spring.datasource.password=${DB_SENHA}
spring.jpa.hibernate.ddl-auto=none
```

O Spring lê as variáveis de **ambiente** da sua máquina, não o arquivo `.env`. Defina `DB_USUARIO` e `DB_SENHA` com os **mesmos valores do `.env`**. Na IDE, isso fica em *Run Configuration → Environment variables* (IntelliJ: `DB_USUARIO=gerenciador;DB_SENHA=troque_esta_senha`).

`ddl-auto=none` porque as tabelas vêm do script deste repositório, e o Hibernate não deve criar nem alterar nada.

## Tabelas

| Tabela | O que guarda |
|---|---|
| `cadastro` | O aluno (nome, email, telefone, data de nascimento, senha) |
| `materia` | Matérias de cada aluno (nome, professor, cor) |
| `tarefa` | Trabalhos e entregas com prazo, prioridade e status |
| `avaliacao` | Provas, testes e exames, com data e nota |
| `calendario` (view) | Junta tarefas e avaliações em uma única linha do tempo |

Relacionamentos: `materia`, `tarefa` e `avaliacao` pertencem a um `cadastro`. `tarefa` e `avaliacao` apontam para uma `materia` (na tarefa é opcional).

Comportamento ao apagar:

- apagar um `cadastro` apaga tudo dele (matérias, tarefas e avaliações);
- apagar uma `materia` apaga as avaliações dela, mas as tarefas ficam sem matéria.

Valores fixos (guardados como texto em maiúsculas):

- `tarefa.prioridade`: `BAIXA`, `MEDIA`, `ALTA`
- `tarefa.status`: `PENDENTE`, `EM_ANDAMENTO`, `CONCLUIDA`
- `avaliacao.tipo`: `PROVA`, `TESTE`, `EXAME`, `OUTRO`

## Para quem cuida do back-end: ajustes nas entidades

O script segue a entidade `Cadastro` atual, com duas exceções:

1. **`telefone`** é `VARCHAR(20)` no banco. Na entidade, trocar `Integer` por `String` (um `Integer` não comporta número com DDD).
2. **`confirmacaoSenha`** não existe no banco. Remover o campo da entidade e manter só no DTO, para validar se as duas senhas conferem.

Além disso:

- Os ids usam sequences (`cadastro_seq`, `materia_seq`, `tarefa_seq`, `avaliacao_seq`) com incremento 50, que é o que o Hibernate espera em `@GeneratedValue(strategy = GenerationType.AUTO)`. As novas entidades devem usar a mesma estratégia.
- As colunas são em `snake_case` (`data_nascimento`), e o Spring converte `dataNascimento` automaticamente.
- Os valores fixos (`prioridade`, `status`, `tipo`) devem ser enums Java com `@Enumerated(EnumType.STRING)`, com os mesmos nomes listados acima.
- `data_nascimento` é `DATE`: funciona com `java.util.Date`, mas `LocalDate` é mais direto.
- A coluna `senha` deve receber o **hash** da senha (por exemplo BCrypt), nunca a senha pura.
- O email é único **sem diferenciar maiúsculas de minúsculas** (`Ana@x.com` e `ana@x.com` contam como o mesmo). O `findByEmail` deve buscar em minúsculas, ou usar `findByEmailIgnoreCase`.

## Sem Docker (PostgreSQL instalado na máquina)

```bash
psql -U postgres -c "CREATE DATABASE gerenciador_tarefas;"
psql -U postgres -d gerenciador_tarefas -f 01_criar_tabelas.sql
```

## Alterando o banco

Mudanças nas tabelas passam por quem cuida do banco: edite o `01_criar_tabelas.sql`, abra um Pull Request e avise o time para recriar o banco local (`docker compose down -v && docker compose up -d`).
