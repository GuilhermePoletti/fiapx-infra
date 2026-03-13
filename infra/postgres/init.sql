-- =============================================================================
-- FIAP X — Script de Inicialização do PostgreSQL
-- =============================================================================
-- QUANDO É EXECUTADO?
--   Apenas na PRIMEIRA vez que o container do Postgres sobe.
--   O Docker monta este arquivo na pasta /docker-entrypoint-initdb.d/ do container.
--   Qualquer .sql nessa pasta é executado automaticamente na inicialização.
--
-- O QUE FAZ?
--   Cria 3 bancos de dados isolados, um para cada microsserviço que precisa
--   de persistência. Isso segue o padrão "Database-per-Service" do DDD.
--
-- POR QUE BANCOS SEPARADOS?
--   Cada microsserviço é dono dos seus dados. Se amanhã o Auth mudar a
--   tabela de usuários, o Video Manager não é afetado (e vice-versa).
--   É PROIBIDO compartilhar tabelas entre serviços.
--
-- BANCOS CRIADOS:
--   1. auth_db         → Auth Service (usuários, credenciais, tokens)
--   2. video_db        → Video Manager (metadados de vídeos, status, links)
--   3. notification_db → Notifier (histórico de e-mails enviados)
-- =============================================================================

-- ─────────────────────────────────────────────
-- BANCO 1: Contexto de Identidade e Acesso
-- ─────────────────────────────────────────────
-- Usado pelo Auth Service para armazenar usuários e credenciais.
-- O Prisma do serviço "auth" vai apontar para este banco.
CREATE DATABASE auth_db;

-- ─────────────────────────────────────────────
-- BANCO 2: Contexto de Ciclo de Vida do Vídeo
-- ─────────────────────────────────────────────
-- Usado pelo Video Manager para armazenar metadados dos vídeos:
--   - ID do vídeo, nome original, status (RECEBIDO, PROCESSANDO, CONCLUIDO, ERRO)
--   - Caminho no MinIO (bucket + key)
--   - ID do usuário dono (referência lógica, NÃO foreign key para auth_db)
-- O Prisma do serviço "manager" vai apontar para este banco.
CREATE DATABASE video_db;

-- ─────────────────────────────────────────────
-- BANCO 3: Contexto de Notificação
-- ─────────────────────────────────────────────
-- Usado pelo Notifier para guardar histórico de e-mails enviados:
--   - Para quem foi enviado, quando, qual evento disparou, se foi sucesso/falha
-- O Prisma do serviço "notifier" vai apontar para este banco.
CREATE DATABASE notification_db;

-- =============================================================================
-- NOTA: As TABELAS de cada banco serão criadas pelo Prisma Migrate de cada
-- serviço (npx prisma migrate dev). Este script só cria os bancos vazios.
--
-- NOTA 2: O banco "postgres" (padrão) continua existindo mas não usamos.
-- O Kong terá seu próprio Postgres (container separado: kong-db).
-- =============================================================================