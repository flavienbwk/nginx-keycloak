# Nginx Keycloak

[![Linux build of nginx-keycloak](https://github.com/flavienbwk/nginx-keycloak/actions/workflows/linux-build.yml/badge.svg)](https://github.com/flavienbwk/nginx-keycloak/actions/workflows/linux-build.yml)

Setting NGINX as a reverse proxy with Keycloak SSO in front of your web applications.

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

    1. In sidebar, click ["Clients"](http://localhost:3333/auth/admin/master/console/#/realms/master/clients) and click on the "Create" button. Let's call it `NginxApps`.
    2. In `NginxApps` client parameters :
       1. Add a "Valid Redirect URI" to your app : `http://172.17.0.1:3002/*` (don't forget clicking "+" button to add the URL, then "Save" button)
       2. Set the "Access type" to `confidential`
    3. In the "Credentials" tab, retrieve the "Secret" and **set `KEYCLOAK_SECRET` in your `.env`** file

5. Go to ["Users"](http://localhost:3333/auth/admin/master/console/#/realms/master/users) in the sidebar and create one. Edit its password in the "Credentials" tab.

### Simple user authentication

With this method, being a registered user is sufficient to access your apps.

If you choose this method, you're already set. Just run :

```bash
docker-compose up -d nginx app_1
```

You can now visit `http://172.17.0.1:3002` to validate the configuration.

### Role-based / per-app user authentication

Let's say you want only specific users to be able to access specific apps. We have to create a role for that.

1. In sidebar, click "Clients"
2. Select the `NginxApps` client and go to the "Roles" tab
3. Top right, click the "Add Role" button and create one with name `NginxApps-App1`

    :information_source: 1 role = 1 app

Now we want to attribute this role to our user.

1. In sidebar, click "Users"
2. Click "Edit" on the user you want to add the role to
3. Go to the "Role Mappings" tab
4. Select the "Client Roles" `NginxApps` and assign the `NginxApps-App1` role by selecting it and clicking "Add selected"

In our [docker-compose](./docker-compose.yml) configuration, edit the NGINX configuration mount point to be `./nginx-roles.conf.template` instead of `./nginx.conf.template`.

:information_source: If you want to name your role differently, you can edit the expected name in `./nginx-roles.conf.template` in the `contains(client_roles, "NginxApps-App1")` line.

Start NGINX and the app :

```bash
docker-compose up -d nginx app_1
```

You can now visit `http://172.17.0.1:3002` to validate the configuration.

## Credits

- [Configure NGINX and Keycloak to enable SSO for proxied applications](https://kevalnagda.github.io/configure-nginx-and-keycloak-to-enable-sso-for-proxied-applications)
