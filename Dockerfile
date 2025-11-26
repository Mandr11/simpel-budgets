# ------------------------------------
# 1. Builder Stage (Install ALL dependencies to generate correct autoloader)
# ------------------------------------
FROM php:8.1-fpm as builder

# Install core build dependencies
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip

WORKDIR /var/www/html
COPY . /var/www/html/

# Copy Composer binary from its dedicated image (as you were doing)
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Install ALL dependencies (without --no-dev) to allow post-install scripts to run successfully.
# This generates the correct vendor and autoloader files.
RUN composer install --optimize-autoloader

# ------------------------------------
# 2. Final Stage (Build the clean production image)
# ------------------------------------
FROM php:8.1-fpm

WORKDIR /var/www/html

# Re-install only the necessary production system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip

# Copy all application files (excluding the large vendor directory)
COPY . /var/www/html/

# Copy ONLY the clean vendor directory from the builder stage
COPY --from=builder /var/www/html/vendor /var/www/html/vendor
COPY --from=builder /var/www/html/composer.lock /var/www/html/composer.lock

# Optional: Ensure autoloader is clean in the final image (requires composer binary)
# COPY --from=composer /usr/bin/composer /usr/bin/composer
# RUN composer dump-autoload --optimize --no-dev --no-scripts

EXPOSE 8000
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
