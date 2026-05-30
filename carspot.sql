CREATE TABLE IF NOT EXISTS `carspot_profiles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `username` VARCHAR(50) NOT NULL,
    `bio` TEXT DEFAULT '',
    `avatar` LONGTEXT DEFAULT '',
    `banner` LONGTEXT DEFAULT '',
    `followers` INT DEFAULT 0,
    `following` INT DEFAULT 0,
    `post_count` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `carspot_followers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `follower_citizenid` VARCHAR(50) NOT NULL,
    `following_citizenid` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_follow` (`follower_citizenid`, `following_citizenid`),
    INDEX `idx_follower` (`follower_citizenid`),
    INDEX `idx_following` (`following_citizenid`)
);

CREATE TABLE IF NOT EXISTS `carspot_posts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT DEFAULT '',
    `image` LONGTEXT DEFAULT '',
    `location` VARCHAR(255) DEFAULT '',
    `vehicle_brand` VARCHAR(100) DEFAULT '',
    `vehicle_model` VARCHAR(100) DEFAULT '',
    `vehicle_plate` VARCHAR(20) DEFAULT '',
    `vehicle_color` VARCHAR(50) DEFAULT '',
    `vehicle_mods` TEXT DEFAULT '',
    `vehicle_class` VARCHAR(50) DEFAULT '',
    `likes_count` INT DEFAULT 0,
    `comments_count` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_created_at` (`created_at`),
    INDEX `idx_vehicle_class` (`vehicle_class`)
);

CREATE TABLE IF NOT EXISTS `carspot_post_likes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `post_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_like` (`post_id`, `citizenid`),
    INDEX `idx_post_id` (`post_id`),
    INDEX `idx_citizenid` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `carspot_post_comments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `post_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `username` VARCHAR(50) NOT NULL,
    `avatar` LONGTEXT DEFAULT '',
    `content` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_post_id` (`post_id`),
    INDEX `idx_citizenid` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `carspot_saved_posts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `post_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_save` (`post_id`, `citizenid`),
    INDEX `idx_citizenid` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `carspot_garage` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `vehicle_brand` VARCHAR(100) NOT NULL,
    `vehicle_model` VARCHAR(100) NOT NULL,
    `vehicle_plate` VARCHAR(20) DEFAULT '',
    `vehicle_color` VARCHAR(50) DEFAULT '',
    `vehicle_mods` TEXT DEFAULT '',
    `vehicle_class` VARCHAR(50) DEFAULT '',
    `mileage` INT DEFAULT 0,
    `purchase_date` DATE DEFAULT NULL,
    `image` LONGTEXT DEFAULT '',
    `likes_count` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `carspot_events` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT DEFAULT '',
    `type` VARCHAR(50) DEFAULT 'car_meet',
    `location` VARCHAR(255) DEFAULT '',
    `event_time` DATETIME NOT NULL,
    `max_participants` INT DEFAULT 50,
    `attendee_count` INT DEFAULT 0,
    `image` LONGTEXT DEFAULT '',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_event_time` (`event_time`)
);

CREATE TABLE IF NOT EXISTS `carspot_event_attendees` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `event_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `notify` TINYINT(1) DEFAULT 0,
    `reminder_sent` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_attend` (`event_id`, `citizenid`),
    INDEX `idx_event_id` (`event_id`),
    INDEX `idx_citizenid` (`citizenid`)
);
