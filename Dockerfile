# 1) Build Stage: Composer + Node (Assets)
FROM ghcr.io/railwayapp/nixpacks:debian as build
# Alternativ: php:8.3-cli + node wäre auch möglich – hier nutzen wir ein schlankes Build-Image mit bash/git etc.

WORKDIR /app
COPY . .

#curl, git, unzip installieren
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git unzip && \
    rm -rf /var/lib/apt/lists/*

# PHP/Composer installieren
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Abhängigkeiten
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Node/PNPM installieren
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && npm i -g pnpm

RUN pnpm install
RUN pnpm run build

# 2) Runtime Stage: PHP-FPM
FROM php:8.3-fpm-alpine

# System libs & PHP Extensions
RUN apk add --no-cache bash libpng-dev libjpeg-turbo-dev libzip-dev oniguruma-dev icu-dev \
    && docker-php-ext-configure gd \
    && docker-php-ext-install gd pdo pdo_mysql mbstring zip intl opcache

WORKDIR /var/www/html

# Code übernehmen
COPY --from=build /app /var/www/html

# Rechte für Storage/Bootstrap
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Expose PHP-FPM
EXPOSE 9000

# Healthcheck optional
HEALTHCHECK --interval=30s --timeout=3s \
  CMD php -v || exit 1

CMD ["php-fpm"]