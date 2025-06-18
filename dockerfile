FROM php:8.2-apache

# Habilita o módulo rewrite do Apache para usar URLs amigáveis com .htaccess
RUN a2enmod rewrite

# Instala a extensão mysqli para a comunicação com o MySQL
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# Copia os arquivos da aplicação para o diretório web do contêiner
COPY . /var/www/html/

# Cria o diretório para uploads e define as permissões
RUN mkdir -p /var/www/html/uploads && \
    chown -R www-data:www-data /var/www/html/uploads && \
    chmod -R 755 /var/www/html/uploads

# Expõe a porta 80 para o tráfego web
EXPOSE 80
