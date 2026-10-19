-- =====================================================================
-- Gerenciador de Tarefas Escolares - criação do banco (PostgreSQL)
-- =====================================================================
-- Convenções (as mesmas do back-end):
--   * tabelas em português, minúsculas e no singular (ex.: cadastro)
--   * colunas em snake_case: o Spring/Hibernate converte camelCase para
--     snake_case (dataNascimento -> data_nascimento)
--   * id BIGINT com sequence <tabela>_seq e INCREMENT 50, que é o padrão
--     do Hibernate para @GeneratedValue(strategy = GenerationType.AUTO)
--   * valores de enum guardados como texto em MAIÚSCULAS
--     (@Enumerated(EnumType.STRING))
--
-- Como rodar (banco vazio):
--   psql -U postgres -d gerenciador_tarefas -f banco/01_criar_tabelas.sql
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Sequences dos ids
-- ---------------------------------------------------------------------
CREATE SEQUENCE cadastro_seq  START WITH 1 INCREMENT BY 50;
CREATE SEQUENCE materia_seq   START WITH 1 INCREMENT BY 50;
CREATE SEQUENCE tarefa_seq    START WITH 1 INCREMENT BY 50;
CREATE SEQUENCE avaliacao_seq START WITH 1 INCREMENT BY 50;

-- ---------------------------------------------------------------------
-- cadastro: o aluno (usuário do sistema)
-- ---------------------------------------------------------------------
CREATE TABLE cadastro (
    id               BIGINT       PRIMARY KEY,
    nome             VARCHAR(255) NOT NULL,
    email            VARCHAR(255) NOT NULL,
    telefone         VARCHAR(20)  NOT NULL,   -- texto: Integer não comporta DDD + número
    data_nascimento  DATE         NOT NULL,
    senha            VARCHAR(255) NOT NULL    -- guardar o HASH da senha, nunca a senha pura
);

-- email único sem diferenciar maiúsculas de minúsculas
-- (no PostgreSQL 'A@x.com' e 'a@x.com' seriam valores diferentes)
CREATE UNIQUE INDEX uk_cadastro_email ON cadastro (LOWER(email));

-- ---------------------------------------------------------------------
-- materia: disciplinas de cada aluno
-- ---------------------------------------------------------------------
CREATE TABLE materia (
    id           BIGINT       PRIMARY KEY,
    cadastro_id  BIGINT       NOT NULL REFERENCES cadastro (id) ON DELETE CASCADE,
    nome         VARCHAR(100) NOT NULL,
    professor    VARCHAR(150),
    cor          VARCHAR(7),                  -- cor de destaque no formato #RRGGBB
    CONSTRAINT uk_materia_cadastro_nome UNIQUE (cadastro_id, nome),
    CONSTRAINT ck_materia_cor CHECK (cor IS NULL OR cor ~ '^#[0-9A-Fa-f]{6}$')
);

-- ---------------------------------------------------------------------
-- tarefa: trabalhos, exercícios e demais entregas com prazo
-- ---------------------------------------------------------------------
CREATE TABLE tarefa (
    id              BIGINT       PRIMARY KEY,
    cadastro_id     BIGINT       NOT NULL REFERENCES cadastro (id) ON DELETE CASCADE,
    materia_id      BIGINT       REFERENCES materia (id) ON DELETE SET NULL,  -- tarefa pode existir sem matéria
    titulo          VARCHAR(150) NOT NULL,
    descricao       TEXT,
    data_entrega    TIMESTAMP    NOT NULL,
    prioridade      VARCHAR(10)  NOT NULL DEFAULT 'MEDIA',
    status          VARCHAR(15)  NOT NULL DEFAULT 'PENDENTE',
    data_conclusao  TIMESTAMP,
    data_criacao    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_tarefa_prioridade CHECK (prioridade IN ('BAIXA', 'MEDIA', 'ALTA')),
    CONSTRAINT ck_tarefa_status     CHECK (status IN ('PENDENTE', 'EM_ANDAMENTO', 'CONCLUIDA'))
);

CREATE INDEX idx_tarefa_cadastro_entrega ON tarefa (cadastro_id, data_entrega);
CREATE INDEX idx_tarefa_cadastro_status  ON tarefa (cadastro_id, status);
CREATE INDEX idx_tarefa_materia          ON tarefa (materia_id);

-- ---------------------------------------------------------------------
-- avaliacao: provas, testes e exames (datas de exames)
-- ---------------------------------------------------------------------
CREATE TABLE avaliacao (
    id              BIGINT        PRIMARY KEY,
    cadastro_id     BIGINT        NOT NULL REFERENCES cadastro (id) ON DELETE CASCADE,
    materia_id      BIGINT        NOT NULL REFERENCES materia (id) ON DELETE CASCADE,
    titulo          VARCHAR(150)  NOT NULL,
    tipo            VARCHAR(10)   NOT NULL DEFAULT 'PROVA',
    data_avaliacao  TIMESTAMP     NOT NULL,
    conteudo        TEXT,                        -- assunto que vai cair
    nota            NUMERIC(4,2),                -- preenchida depois da correção
    nota_maxima     NUMERIC(4,2)  NOT NULL DEFAULT 10,
    data_criacao    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_avaliacao_tipo CHECK (tipo IN ('PROVA', 'TESTE', 'EXAME', 'OUTRO')),
    CONSTRAINT ck_avaliacao_nota CHECK (nota IS NULL OR (nota >= 0 AND nota <= nota_maxima))
);

CREATE INDEX idx_avaliacao_cadastro_data ON avaliacao (cadastro_id, data_avaliacao);
CREATE INDEX idx_avaliacao_materia       ON avaliacao (materia_id);

-- ---------------------------------------------------------------------
-- calendario: visão que junta tarefas e avaliações em uma linha do tempo
-- (a tela de Calendário só precisa consultar esta view)
-- ---------------------------------------------------------------------
CREATE VIEW calendario AS
SELECT 'TAREFA'::VARCHAR(10)   AS origem,
       t.id,
       t.cadastro_id,
       t.materia_id,
       t.titulo,
       t.data_entrega          AS data_evento,
       t.status
FROM tarefa t
UNION ALL
SELECT 'AVALIACAO'::VARCHAR(10),
       a.id,
       a.cadastro_id,
       a.materia_id,
       a.titulo,
       a.data_avaliacao,
       NULL::VARCHAR(15)
FROM avaliacao a;

COMMIT;
