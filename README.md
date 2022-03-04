# Nginx Keycloak

Set an NGINX reverse proxy with Keycloak SSO in front of your web applications

## Getting started

### Configuring Keycloak

1. Set-up `.env` and edit variable values

    ```bash
    cp .env.example .env
    ```

2. Start Keycloak

    ```bash
    docker-compose up -d keycloak
    ```

3. Go to `http://localhost:3333` and login with your credentials

4. In the [master realm](http://localhost:3333/auth/admin/master/console/#/realms/master), we are going to create a client

    1. Click ["Clients"](http://localhost:3333/auth/admin/master/console/#/realms/master/clients) on the sidebar and click on the "Create" button. Let's call it `MySecureApp`.
    2. In the client parameters :
       1. Add a "Valid Redirect URI" to your app : `http://localhost:3002/*` (don't forget clicking "+" button to add the URL, then "Save" button)
       2. Set the "Access type" to `confidential`
    3. In the "Credentials" tab, retrieve the "Secret" and **set `KEYCLOAK_SECRET` in your `.env`** file

5. Go to ["Users"](http://localhost:3333/auth/admin/master/console/#/realms/master/users) in the sidebar and create one. Edit its password in the "Credentials" tab.

### Start NGINX and your app

```bash
docker-compose up -d nginx app_1
```

You can now visit `http://localhost:3002` to validate the configuration.

## Credits

- [Configure NGINX and Keycloak to enable SSO for proxied applications](https://kevalnagda.github.io/configure-nginx-and-keycloak-to-enable-sso-for-proxied-applications)
