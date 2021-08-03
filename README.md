# ContactForm

## Paging on your local machine

```
cd /tmp
rsync -Pave 'ssh' contact.doma.dev:/tmp/messages .
cd messages
find . -type f -exec less {} \; -exec rm {} \;
```

Patch to send messages as E-Mails to a designated mailbox is more than welcome.

## Run in production

### Phoenix

Assuming you have set up DNS and NGINX you know it will work with certbot, simply run `./run.sh`. NB! It will drop you in the interactive shell.

Otherwise, consult the following sections.
Also, take a precaution and first test that certificate acquisition works by setting mode to `:manual` in [SiteEncrypt config](https://hexdocs.pm/site_encrypt/0.4.2/SiteEncrypt.html#configure/1-options).
When you do, you can perform a dry run of certificate acquisition.

### Certbot

```
sudo snap install certbot --classic
```

### NGINX

```
server {
	server_name contact.doma.dev;
	charset utf-8;

	location / {
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:4000;
	}

	listen 443 ssl;
	ssl_certificate /home/sweater/doma/contact_form/tmp/site_encrypt_db/certbot/acme-v02.api.letsencrypt.org/config/live/contact.doma.dev/fullchain.pem;
	ssl_certificate_key /home/sweater/doma/contact_form/tmp/site_encrypt_db/certbot/acme-v02.api.letsencrypt.org/config/live/contact.doma.dev/privkey.pem;
	include /etc/letsencrypt/options-ssl-nginx.conf; # install Certbot!
	ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # install Certbot
}

server {
	if ($host = ctf.cdn.doma.dev) {
		return 301 https://$host$request_uri;
	} 

	listen 80;
	server_name contact.doma.dev;
	return 404;
}
```
