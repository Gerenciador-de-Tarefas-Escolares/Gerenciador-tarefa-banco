# Banco de dados

Banco do Gerenciador de Tarefas Escolares, em **PostgreSQL**.

## Tabelas

| Tabela | O que guarda |
|---|---|
| `cadastro` | O aluno (nome, email, telefone, data de nascimento, senha) |
| `materia` | Matérias de cada aluno (nome, professor, cor) |
| `tarefa` | Trabalhos e entregas com prazo, prioridade e status |
| `avaliacao` | Provas, testes e exames, com data e nota |
| `calendario` (view) | Junta tarefas e avaliações em uma única linha do tempo |

Relacionamentos: `materia`, `tarefa` e `avaliacao` pertencem a um `cadastro`. `tarefa` e `avaliacao` apontam para uma `materia` (na tarefa é opcional).

Valores fixos (guardados como texto em maiúsculas):

- `tarefa.prioridade`: `BAIXA`, `MEDIA`, `ALTA`
- `tarefa.status`: `PENDENTE`, `EM_ANDAMENTO`, `CONCLUIDA`
- `avaliacao.tipo`: `PROVA`, `TESTE`, `EXAME`, `OUTRO`

## Como criar o banco

```bash
psql -U postgres -c "CREATE DATABASE gerenciador_tarefas;"
psql -U postgres -d gerenciador_tarefas -f banco/01_criar_tabelas.sql
```

Para conferir: `psql -U postgres -d gerenciador_tarefas -c "\dt"`

## Conexão no back-end

No `application.properties`, **sem colocar senha no arquivo** (o repositório é público):

```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/gerenciador_tarefas
spring.datasource.username=${DB_USUARIO}
spring.datasource.password=${DB_SENHA}
spring.jpa.hibernate.ddl-auto=none
```

Cada pessoa define `DB_USUARIO` e `DB_SENHA` como variáveis de ambiente na própria máquina.

## Ajustes necessários nas entidades

O script segue a entidade `Cadastro` atual, com duas exceções que precisam ser alinhadas com quem cuida do back-end:

1. **`telefone`** é `VARCHAR(20)` no banco. Na entidade, trocar `Integer` por `String` (um `Integer` não comporta número com DDD).
2. **`confirmacaoSenha`** não existe no banco. Remover o campo da entidade e manter só no DTO, para validar se as duas senhas conferem.

Além disso:

- Os ids usam sequences (`cadastro_seq`, `materia_seq`, `tarefa_seq`, `avaliacao_seq`) com incremento 50, como o Hibernate espera em `GenerationType.AUTO`. As novas entidades devem usar a mesma estratégia.
- `data_nascimento` é `DATE`. Se a entidade continuar com `java.util.Date`, funciona; com `LocalDate` fica mais direto. Só use `ddl-auto=validate` depois de alinhar esses tipos.
- A coluna `senha` deve receber o **hash** da senha (por exemplo BCrypt), nunca a senha pura.
