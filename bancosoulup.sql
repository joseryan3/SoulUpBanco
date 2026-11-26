DROP DATABASE IF EXISTS soulup_db;
CREATE DATABASE soulup_db;
USE soulup_db;

-- =========================================================================
-- 1. USUÁRIOS E SEGURANÇA
-- =========================================================================

CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100) UNIQUE NULL,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    tipo ENUM('USUARIO', 'ADMIN', 'MODERADOR') DEFAULT 'USUARIO',
    imagem_perfil VARCHAR(255),
    premium BOOLEAN DEFAULT FALSE,
    plano_tipo VARCHAR(50) DEFAULT 'FREE', -- Ex: MENSAL, ANUAL, FREE
    data_expiracao_assinatura DATETIME NULL,
    perfil_publico BOOLEAN DEFAULT TRUE,
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE password_reset_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE,
    usuario_id INT NOT NULL,
    data_expiracao DATETIME NOT NULL,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

CREATE TABLE user_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL UNIQUE,
    language VARCHAR(10) DEFAULT 'pt-BR',
    public_profile BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT TRUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- =========================================================================
-- 2. ARQUIVOS DE VÍDEO E ANÁLISES DE IA
-- =========================================================================

CREATE TABLE videos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NULL, -- NULL caso o upload inicial não passe o objeto User logado
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    content_type VARCHAR(50), -- MP4 ou MOV
    size BIGINT,
    status VARCHAR(50) DEFAULT 'PENDENTE', -- PENDENTE, PROCESSANDO, CONCLUIDO, ERRO
    score DOUBLE NULL,
    tipo_exercicio VARCHAR(100) NULL,      -- Necessário para as buscas por ignore case
    nivel_dificuldade VARCHAR(50) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE analysis_results (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    video_id BIGINT NOT NULL UNIQUE, -- Relacionamento @OneToOne
    suggestions LONGTEXT,            -- Mapeado do @Lob do Java
    accuracy_score DOUBLE,
    processed_at DATETIME NOT NULL,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE
);

-- =========================================================================
-- 3. INTERAÇÕES E FEEDBACKS DA IA
-- =========================================================================

CREATE TABLE feedbacks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    analysis_result_id BIGINT UNIQUE,
    detailed_comment TEXT,
    visual_markers TEXT,             -- Guardará o JSON de coordenadas do Java
    correction_tip VARCHAR(255),
    FOREIGN KEY (analysis_result_id) REFERENCES analysis_results(id) ON DELETE CASCADE
);

CREATE TABLE ratings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NULL,
    analysis_result_id BIGINT UNIQUE, -- Campo cobrado explicitamente pelo RatingController
    stars INT NOT NULL CHECK (stars BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL,
    FOREIGN KEY (analysis_result_id) REFERENCES analysis_results(id) ON DELETE CASCADE
);

CREATE TABLE favorites (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    video_id BIGINT NOT NULL,
    category VARCHAR(100) DEFAULT 'Geral',
    favorited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE,
    CONSTRAINT unique_user_video_favorite UNIQUE (usuario_id, video_id)
);

-- =========================================================================
-- 4. COMUNIDADE SOCIAL E MODERAÇÃO
-- =========================================================================

CREATE TABLE posts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    video_id BIGINT UNIQUE NULL,     -- O post compartilha um vídeo analisado
    legenda VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE SET NULL
);

CREATE TABLE comments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT NOT NULL,         -- Alterado de video para bater com o CommunityService
    usuario_id INT NOT NULL,
    text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Tabela associativa do relacionamento @ManyToMany de curtidas em Posts
CREATE TABLE post_likes (
    post_id BIGINT NOT NULL,
    user_id INT NOT NULL,
    PRIMARY KEY (post_id, user_id),
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Suporte a logs de moderação (Denuncia / Report)
CREATE TABLE denuncias (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT NOT NULL,
    denunciante_id INT NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    data_denuncia TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (denunciante_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

CREATE TABLE reports (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,         -- Quem denunciou
    post_id BIGINT NULL,
    comment_id BIGINT NULL,
    reason VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDENTE', -- PENDENTE, ANALISADO, REJEITADO
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE
);

-- =========================================================================
-- 5. FINANCEIRO E SUPORTE
-- =========================================================================

CREATE TABLE payments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    amount DOUBLE NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDENTE', -- PENDENTE, APROVADO, CANCELADO
    payment_method VARCHAR(50),            -- PIX, CREDIT_CARD
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

CREATE TABLE support_tickets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    subject VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'ABERTO',   -- ABERTO, FECHADO
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

CREATE TABLE notificacoes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'SISTEMA',    -- ANALYSIS_READY, SUPPORT_REPLY, etc.
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- =========================================================================
-- 6. GAMIFICAÇÃO E DESAFIOS
-- =========================================================================

CREATE TABLE achievements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    icon_url VARCHAR(255)
);

CREATE TABLE user_progress (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL UNIQUE,
    total_points INT DEFAULT 0,
    level INT DEFAULT 1,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Tabela associativa das conquistas do usuário (@ManyToMany)
CREATE TABLE user_achievements (
    user_progress_id INT NOT NULL,
    achievement_id INT NOT NULL,
    PRIMARY KEY (user_progress_id, achievement_id),
    FOREIGN KEY (user_progress_id) REFERENCES user_progress(id) ON DELETE CASCADE,
    FOREIGN KEY (achievement_id) REFERENCES achievements(id) ON DELETE CASCADE
);

CREATE TABLE challenge (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    points_reward INT NOT NULL,
    deadline DATETIME NOT NULL
);

-- =========================================================================
-- 7. TABELA EXTRA (LEGACY / EXPERIMENTAL)
-- =========================================================================

CREATE TABLE soul_up (
    id BIGINT PRIMARY KEY,
    matricula INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    curso VARCHAR(100) NOT NULL
);