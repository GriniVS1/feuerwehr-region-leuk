# --- Build Stage ---
FROM composer:2 as build

WORKDIR /app
COPY . .

# Dependencies installieren
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Node & Vite für Assets
FROM node:20-alpine as assets
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install
COPY . .
RUN pnpm run build

# --- Runtime Stage ---
FROM php:8.3-fpm-alpine

RUN apk add --no-cache bash libpng-dev libjpeg-turbo-dev libzip-dev oniguruma-dev icu-dev \
  && docker-php-ext-configure gd \
  && docker-php-ext-install gd pdo pdo_mysql mbstring zip intl opcache

WORKDIR /var/www/html
COPY . .
COPY --from=build /app/vendor /var/www/html/vendor
COPY --from=assets /app/public/build /var/www/html/public/build

RUN chown -R www-data:www-data storage bootstrap/cache

EXPOSE 9000
CMD ["php-fpm"]