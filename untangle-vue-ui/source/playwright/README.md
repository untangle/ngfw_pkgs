# NGFW Playwright pilot

This is an appliance-local Playwright harness for the first NGFW Interfaces-screen check. It is intentionally separate from the Vue application dependencies.

## Run

    yarn install
    yarn playwright install chromium

    NGFW_UI_URL='https://<NGFW_UI_HOST>/console/' \\
    NGFW_USERNAME='<USER>' \\
    NGFW_PASSWORD='<REDACTED_SECRET>' \\
    yarn test:interfaces

For the state-changing VLAN CRUD test, use the opt-in CRUD project:

    NGFW_UI_URL='https://<NGFW_UI_HOST>/console/' \\
    NGFW_USERNAME='<USER>' \\
    NGFW_PASSWORD='<REDACTED_SECRET>' \\
    yarn test:interfaces-crud

NGFW_UI_URL must point to the reachable appliance or development UI, including its actual protocol, host, port, and `/console/` base path. The setup project logs in through the appliance UI and stores the browser session in .auth/admin.json; each feature project then reuses that state.

Use NGFW_STORAGE_STATE to place the generated storage state elsewhere. Do not commit credentials or storage-state files.
