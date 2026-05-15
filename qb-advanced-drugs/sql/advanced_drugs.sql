CREATE TABLE IF NOT EXISTS `advanced_drugs` (
  `id` varchar(64) NOT NULL,
  `label` varchar(128) NOT NULL,
  `data` longtext NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
