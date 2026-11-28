# syntax=docker/dockerfile:1
ARG PHP_VERSION=8.4
ARG NODE_VERSION=22

# ---------------------------------------------------------------- base --------
FROM php:${PHP_VERSION}-fpm-bookworm AS base

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libfcgi-bin \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libonig-dev \
        libpng-dev \
        libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        gd \
        intl \
        opcache \
        pcntl \
        pdo_mysql \
        zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install the pool configuration the healthcheck depends on. `zz-` prefix so it
# wins over the image's default www.conf, which does not define the ping path.
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/zz-app.conf

# -------------------------------------------------------------- vendor --------
FROM base AS vendor
WORKDIR /app
# Globs so the stack can be dropped into a project that has no lock file yet.
# Production images should build from a committed composer.lock; CI builds the
# fixture app, which has none, to prove the Dockerfile works either way.
COPY composer.json composer.lock* ./
RUN if [ -f composer.lock ]; then \
        composer install --no-dev --no-scripts --no-autoloader --prefer-dist \
            --no-interaction --no-progress; \
    else \
        composer update --no-dev --no-scripts --no-autoloader --prefer-dist \
            --no-interaction --no-progress; \
    fi
COPY . .
RUN composer dump-autoload --optimize --no-dev --no-interaction

# -------------------------------------------------------------- assets --------
FROM node:${NODE_VERSION}-alpine AS assets
WORKDIR /app
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then \
        npm ci --no-audit --no-fund; \
    else \
        npm install --no-audit --no-fund; \
    fi
COPY . .
RUN npm run build

# ------------------------------------------------------------- runtime --------
FROM base AS runtime

ARG UID=1000
ARG GID=1000

RUN groupadd --gid "${GID}" app \
    && useradd --uid "${UID}" --gid app --create-home --shell /bin/bash app

WORKDIR /var/www/html

COPY --chown=app:app --from=vendor /app/vendor ./vendor
COPY --chown=app:app --from=assets /app/public/build ./public/build
COPY --chown=app:app . .

RUN mkdir -p \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache \
    && chown -R app:app storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

USER app

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \
        cgi-fcgi -bind -connect 127.0.0.1:9000 | grep -q pong

CMD ["php-fpm"]
