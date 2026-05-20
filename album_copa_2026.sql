-- ============================================================
--  BANCO DE DADOS: Álbum de Figurinhas Copa 2026
--  Gerado a partir da aplicação HTML/JS
--  Compatível com: PostgreSQL / MySQL / SQLite
-- ============================================================

-- ------------------------------------------------------------
-- TABELA: usuarios
-- Representa os irmãos que compartilham o álbum
-- ------------------------------------------------------------
CREATE TABLE usuarios (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        VARCHAR(100)  NOT NULL,
    senha_hash  VARCHAR(64)   NOT NULL,          -- SHA-256 da senha
    criado_em   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- TABELA: secoes
-- Seções do álbum (países/categorias)
-- Extraídas do array JS: ["FWC","USA","MEX","CAN","BRA","ARG",
--   "FRA","GER","ENG","ITA","ESP","POR","JPN","MAR","SEN","ALM"]
-- ------------------------------------------------------------
CREATE TABLE secoes (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo    VARCHAR(10)  NOT NULL UNIQUE,   -- Ex: "BRA", "FWC"
    nome      VARCHAR(100) NOT NULL,
    ordem     INTEGER      NOT NULL           -- Ordem no álbum
);

-- ------------------------------------------------------------
-- TABELA: figurinhas
-- Catálogo completo das 980 figurinhas do álbum
-- ------------------------------------------------------------
CREATE TABLE figurinhas (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    numero     INTEGER      NOT NULL UNIQUE,  -- 1 a 980
    secao_id   INTEGER      NOT NULL,
    FOREIGN KEY (secao_id) REFERENCES secoes(id)
);

-- ------------------------------------------------------------
-- TABELA: album_usuario
-- Estado de cada figurinha por usuário
-- status: 'falta' | 'colada'
-- ------------------------------------------------------------
CREATE TABLE album_usuario (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id    INTEGER   NOT NULL,
    figurinha_id  INTEGER   NOT NULL,
    status        VARCHAR(10) NOT NULL DEFAULT 'falta'
                  CHECK (status IN ('falta', 'colada')),
    repetidas     INTEGER   NOT NULL DEFAULT 0 CHECK (repetidas >= 0),
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (usuario_id, figurinha_id),
    FOREIGN KEY (usuario_id)   REFERENCES usuarios(id),
    FOREIGN KEY (figurinha_id) REFERENCES figurinhas(id)
);

-- ------------------------------------------------------------
-- TABELA: trocas  (extensão sugerida)
-- Registro de trocas de figurinhas entre irmãos
-- ------------------------------------------------------------
CREATE TABLE trocas (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_oferece  INTEGER NOT NULL,
    usuario_recebe   INTEGER NOT NULL,
    figurinha_id     INTEGER NOT NULL,
    status           VARCHAR(15) NOT NULL DEFAULT 'pendente'
                     CHECK (status IN ('pendente', 'concluida', 'cancelada')),
    criado_em        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_oferece) REFERENCES usuarios(id),
    FOREIGN KEY (usuario_recebe)  REFERENCES usuarios(id),
    FOREIGN KEY (figurinha_id)    REFERENCES figurinhas(id)
);


-- ============================================================
--  DADOS INICIAIS
-- ============================================================

-- Seções do álbum (mesma ordem do código JS, 1 seção a cada ~60 figurinhas)
INSERT INTO secoes (codigo, nome, ordem) VALUES
    ('FWC', 'FIFA World Cup',          1),
    ('USA', 'Estados Unidos',          2),
    ('MEX', 'México',                  3),
    ('CAN', 'Canadá',                  4),
    ('BRA', 'Brasil',                  5),
    ('ARG', 'Argentina',               6),
    ('FRA', 'França',                  7),
    ('GER', 'Alemanha',                8),
    ('ENG', 'Inglaterra',              9),
    ('ITA', 'Itália',                 10),
    ('ESP', 'Espanha',                11),
    ('POR', 'Portugal',               12),
    ('JPN', 'Japão',                  13),
    ('MAR', 'Marrocos',               14),
    ('SEN', 'Senegal',                15),
    ('ALM', 'Restante do Álbum',      16);

-- Usuário padrão (senha: copa1234 → hash SHA-256)
INSERT INTO usuarios (nome, senha_hash) VALUES
    ('Irmãos', '34ec6f02971bc7eeaf99f5fc504c53f39f1961c1b1f775cb332cb7058b176621');

-- Figurinhas: 980 no total, seção muda a cada 60 figurinhas
-- (geração via script; abaixo os primeiros exemplos e depois via loop lógico)
-- Seção 1: FWC  → figurinhas  1–60   (secao_id = 1)
-- Seção 2: USA  → figurinhas 61–120  (secao_id = 2)
-- Seção 3: MEX  → figurinhas 121–180 (secao_id = 3)
-- ...e assim por diante até a 980

-- Para popular as 980 figurinhas use o script abaixo no seu SGBD:

-- PostgreSQL / geração automática:
-- INSERT INTO figurinhas (numero, secao_id)
-- SELECT
--     gs AS numero,
--     LEAST(CEIL(gs::numeric / 60), 16)::int AS secao_id
-- FROM generate_series(1, 980) gs;

-- SQLite / geração via WITH RECURSIVE:
WITH RECURSIVE nums(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 980
)
INSERT INTO figurinhas (numero, secao_id)
SELECT
    n,
    MIN(16, ((n - 1) / 60) + 1)
FROM nums;

-- Estado inicial: todas as figurinhas como 'falta' para o usuário 1
INSERT INTO album_usuario (usuario_id, figurinha_id, status, repetidas)
SELECT 1, id, 'falta', 0
FROM figurinhas;


-- ============================================================
--  VIEWS ÚTEIS
-- ============================================================

-- Progresso geral do álbum
CREATE VIEW vw_progresso AS
SELECT
    u.nome                                              AS usuario,
    COUNT(*)                                            AS total_figurinhas,
    SUM(CASE WHEN au.status = 'colada' THEN 1 ELSE 0 END) AS coladas,
    SUM(au.repetidas)                                   AS total_repetidas,
    ROUND(
        SUM(CASE WHEN au.status = 'colada' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1
    )                                                   AS percentual
FROM album_usuario au
JOIN usuarios u ON u.id = au.usuario_id
GROUP BY u.id, u.nome;

-- Figurinhas que faltam
CREATE VIEW vw_faltando AS
SELECT
    u.nome   AS usuario,
    s.codigo AS secao,
    f.numero
FROM album_usuario au
JOIN usuarios    u ON u.id = au.usuario_id
JOIN figurinhas  f ON f.id = au.figurinha_id
JOIN secoes      s ON s.id = f.secao_id
WHERE au.status = 'falta'
ORDER BY f.numero;

-- Figurinhas repetidas disponíveis para troca
CREATE VIEW vw_repetidas AS
SELECT
    u.nome      AS usuario,
    s.codigo    AS secao,
    f.numero,
    au.repetidas
FROM album_usuario au
JOIN usuarios    u ON u.id = au.usuario_id
JOIN figurinhas  f ON f.id = au.figurinha_id
JOIN secoes      s ON s.id = f.secao_id
WHERE au.repetidas > 0
ORDER BY f.numero;

-- Resumo por seção
CREATE VIEW vw_resumo_por_secao AS
SELECT
    u.nome                                                  AS usuario,
    s.codigo                                                AS secao,
    s.nome                                                  AS nome_secao,
    COUNT(*)                                                AS total,
    SUM(CASE WHEN au.status = 'colada' THEN 1 ELSE 0 END)  AS coladas,
    COUNT(*) - SUM(CASE WHEN au.status = 'colada' THEN 1 ELSE 0 END) AS faltando
FROM album_usuario au
JOIN usuarios   u ON u.id = au.usuario_id
JOIN figurinhas f ON f.id = au.figurinha_id
JOIN secoes     s ON s.id = f.secao_id
GROUP BY u.id, u.nome, s.id, s.codigo, s.nome
ORDER BY s.ordem;


-- ============================================================
--  QUERIES DE EXEMPLO
-- ============================================================

-- Ver progresso geral:
-- SELECT * FROM vw_progresso;

-- Ver o que falta por seção:
-- SELECT * FROM vw_resumo_por_secao WHERE usuario = 'Irmãos';

-- Marcar figurinha 42 como colada:
-- UPDATE album_usuario SET status = 'colada', atualizado_em = CURRENT_TIMESTAMP
-- WHERE usuario_id = 1 AND figurinha_id = (SELECT id FROM figurinhas WHERE numero = 42);

-- Adicionar repetida à figurinha 100:
-- UPDATE album_usuario SET repetidas = repetidas + 1, status = 'colada', atualizado_em = CURRENT_TIMESTAMP
-- WHERE usuario_id = 1 AND figurinha_id = (SELECT id FROM figurinhas WHERE numero = 100);

-- Resetar figurinha 55:
-- UPDATE album_usuario SET status = 'falta', repetidas = 0, atualizado_em = CURRENT_TIMESTAMP
-- WHERE usuario_id = 1 AND figurinha_id = (SELECT id FROM figurinhas WHERE numero = 55);

-- Listar repetidas para troca:
-- SELECT * FROM vw_repetidas;
