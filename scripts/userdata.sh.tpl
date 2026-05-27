#!/bin/bash
set -euo pipefail

DB_NAME="${db_name}"
DB_USER="${db_username}"
DB_PASSWORD="${db_password}"
DB_HOST="${db_endpoint}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
DOMAIN_NAME="${domain_name}"
WP_SITE_TITLE="${wp_site_title}"
WP_ADMIN_USER="${wp_admin_user}"
WP_ADMIN_PASSWORD="${wp_admin_password}"
WP_ADMIN_EMAIL="${wp_admin_email}"
WEB_ROOT="/var/www/html"
UPLOADS_DIR="$WEB_ROOT/wp-content/uploads"
CACHE_DIR="/var/cache/s3fs"

export DEBIAN_FRONTEND=noninteractive

apt update -y
apt install -y apache2 php php-cli libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip curl wget unzip git fuse3 libfuse3-dev s3fs mariadb-client

command -v s3fs >/dev/null 2>&1

mkdir -p "$WEB_ROOT"
cd "$WEB_ROOT"
rm -f index.html index.nginx-debian.html

if [ ! -f "$WEB_ROOT/wp-settings.php" ]; then
  wget -q https://wordpress.org/latest.tar.gz
  tar -xzf latest.tar.gz --strip-components=1
  rm -f latest.tar.gz
fi

mkdir -p "$UPLOADS_DIR" "$CACHE_DIR"
chown www-data:www-data "$UPLOADS_DIR" "$CACHE_DIR"
chmod 755 "$UPLOADS_DIR"
grep -q '^user_allow_other' /etc/fuse.conf || echo 'user_allow_other' >> /etc/fuse.conf

if ! mountpoint -q "$UPLOADS_DIR"; then
  for attempt in 1 2 3 4 5 6; do
    if /usr/bin/s3fs "$S3_BUCKET" "$UPLOADS_DIR" -o allow_other,uid=33,gid=33,iam_role=auto,use_cache="$CACHE_DIR",ensure_diskfree=1024,url=https://s3.amazonaws.com,endpoint="$AWS_REGION"; then
      break
    fi
    echo "S3FS mount failed on attempt $attempt. Retrying..."
    sleep 20
  done
fi

if ! mountpoint -q "$UPLOADS_DIR"; then
  echo "S3FS mount failed after retries. Exiting user data."
  exit 1
fi

grep -q "s3fs#$S3_BUCKET $UPLOADS_DIR " /etc/fstab || echo "s3fs#$S3_BUCKET $UPLOADS_DIR fuse _netdev,allow_other,uid=33,gid=33,iam_role=auto,use_cache=$CACHE_DIR,ensure_diskfree=1024,url=https://s3.amazonaws.com,endpoint=$AWS_REGION 0 0" >> /etc/fstab

SALTS=$(curl -fsS https://api.wordpress.org/secret-key/1.1/salt/ || true)
if [ -z "$SALTS" ]; then
  SALTS="define( 'AUTH_KEY',         'change-me-auth-key' );
define( 'SECURE_AUTH_KEY',  'change-me-secure-auth-key' );
define( 'LOGGED_IN_KEY',    'change-me-logged-in-key' );
define( 'NONCE_KEY',        'change-me-nonce-key' );
define( 'AUTH_SALT',        'change-me-auth-salt' );
define( 'SECURE_AUTH_SALT', 'change-me-secure-auth-salt' );
define( 'LOGGED_IN_SALT',   'change-me-logged-in-salt' );
define( 'NONCE_SALT',       'change-me-nonce-salt' );"
fi

cat > "$WEB_ROOT/wp-config.php" << EOF
<?php
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}

define( 'DB_NAME', '$DB_NAME' );
define( 'DB_USER', '$DB_USER' );
define( 'DB_PASSWORD', '$DB_PASSWORD' );
define( 'DB_HOST', '$DB_HOST' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

$SALTS

\$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
define( 'WP_HOME', 'https://$DOMAIN_NAME' );
define( 'WP_SITEURL', 'https://$DOMAIN_NAME' );
define( 'FORCE_SSL_ADMIN', true );
define( 'WP_CONTENT_DIR', '$WEB_ROOT/wp-content' );
define( 'WP_CONTENT_URL', 'https://$DOMAIN_NAME/wp-content' );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF

cat > /etc/apache2/sites-available/000-default.conf << APACHE
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    DocumentRoot $WEB_ROOT

    <Directory $WEB_ROOT>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \$${APACHE_LOG_DIR}/error.log
    CustomLog \$${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
APACHE

a2enmod rewrite
find "$WEB_ROOT" -path "$UPLOADS_DIR" -prune -o -exec chown www-data:www-data {} \;
find "$WEB_ROOT" -path "$UPLOADS_DIR" -prune -o -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -path "$UPLOADS_DIR" -prune -o -type f -exec chmod 644 {} \;
systemctl enable apache2
systemctl restart apache2

until mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting for database connection..."
  sleep 10
done

if ! command -v wp >/dev/null 2>&1; then
  curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
fi

if ! runuser -u www-data -- wp core is-installed --path="$WEB_ROOT" >/dev/null 2>&1; then
  runuser -u www-data -- wp core install --path="$WEB_ROOT" --url="https://$DOMAIN_NAME" --title="$WP_SITE_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email || runuser -u www-data -- wp core is-installed --path="$WEB_ROOT"
fi

THEME_DIR="$WEB_ROOT/wp-content/themes/neatfleets"
mkdir -p "$THEME_DIR"
cat > "$THEME_DIR/style.css" <<'CSS'
/*
Theme Name: NeatFleets Cloud
Author: NeatFleets Services
Version: 1.0.0
*/
CSS

cat > "$THEME_DIR/functions.php" <<'PHP'
<?php
function neatfleets_theme_setup() {
    add_theme_support('title-tag');
}
add_action('after_setup_theme', 'neatfleets_theme_setup');
PHP

cat > "$THEME_DIR/index.php" <<'PHP'
<?php
$status_items = [
    ['title' => 'Autoscaling WordPress', 'body' => 'Traffic reaches a public HTTPS load balancer and is served by private EC2 instances in an Auto Scaling Group.'],
    ['title' => 'S3 Media Filesystem', 'body' => 'Uploaded media is stored on an S3 bucket mounted at wp-content/uploads on every instance.'],
    ['title' => 'Private Database', 'body' => 'WordPress uses a private RDS MySQL database protected by security groups.'],
];
?><!doctype html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <?php wp_head(); ?>
  <style>
    body { margin: 0; font-family: Arial, Helvetica, sans-serif; color: #172033; background: #f5f7fb; }
    .hero { min-height: 72vh; display: grid; place-items: center; padding: 48px 20px; background: linear-gradient(135deg, #0e3b43, #176b63 52%, #f0b429); color: white; }
    .hero-inner { width: min(1120px, 100%); }
    .eyebrow { font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 700; opacity: 0.9; }
    h1 { max-width: 760px; margin: 18px 0; font-size: clamp(42px, 7vw, 86px); line-height: 0.95; }
    .lead { max-width: 720px; font-size: 20px; line-height: 1.6; }
    .actions { display: flex; gap: 14px; flex-wrap: wrap; margin-top: 30px; }
    .button { color: #0e3b43; background: white; padding: 14px 18px; text-decoration: none; font-weight: 700; border-radius: 6px; }
    .button.secondary { color: white; background: rgba(255,255,255,0.16); border: 1px solid rgba(255,255,255,0.46); }
    .section { width: min(1120px, calc(100% - 40px)); margin: 52px auto; }
    .grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 18px; }
    .card { background: white; border: 1px solid #dde4ef; border-radius: 8px; padding: 24px; box-shadow: 0 10px 24px rgba(23,32,51,0.08); }
    .card h2 { margin-top: 0; color: #0e3b43; }
    .meta { color: #5a6578; }
    @media (max-width: 780px) { .grid { grid-template-columns: 1fr; } h1 { font-size: 44px; } }
  </style>
</head>
<body <?php body_class(); ?>>
  <main>
    <section class="hero">
      <div class="hero-inner">
        <div class="eyebrow">NeatFleets Services on AWS</div>
        <h1>WordPress built for scale, secured with HTTPS.</h1>
        <p class="lead">This page is served from WordPress behind an Application Load Balancer. Media uploads are shared through an S3 filesystem mount across the EC2 fleet.</p>
        <div class="actions">
          <a class="button" href="/wp-admin/">WordPress Admin</a>
          <a class="button secondary" href="https://wordpress.neatfleets-services.com">Public Site</a>
        </div>
      </div>
    </section>
    <section class="section">
      <div class="grid">
        <?php foreach ($status_items as $item) : ?>
          <article class="card">
            <h2><?php echo esc_html($item['title']); ?></h2>
            <p><?php echo esc_html($item['body']); ?></p>
          </article>
        <?php endforeach; ?>
      </div>
      <p class="meta">Rendered by WordPress on <?php echo esc_html(get_bloginfo('name')); ?>.</p>
    </section>
  </main>
  <?php wp_footer(); ?>
</body>
</html>
PHP

chown -R www-data:www-data "$THEME_DIR"
runuser -u www-data -- wp theme activate neatfleets --path="$WEB_ROOT" || true
runuser -u www-data -- wp option update permalink_structure '/%postname%/' --path="$WEB_ROOT" || true
runuser -u www-data -- wp rewrite flush --path="$WEB_ROOT" || true

echo "ok" > "$WEB_ROOT/health.html"
chown www-data:www-data "$WEB_ROOT/health.html"
systemctl restart apache2
echo "WordPress setup completed for https://$DOMAIN_NAME with S3 uploads mounted at $UPLOADS_DIR."
