# NetconfEmulator
(Documents under preparing)  
Create a dummy environment from the responses of real NETCONF equipment.


## Environments
- Ubuntu
- Docker
- docker-compose


## How to use
1. hello  
    -> `/etc/SAMPLE/hello.xml`

2. get-schema  
    -> `/etc/SAMPLE/schema/`
    ```bash
    ./schema-list-key /etc/SAMPLE/schema/ > /etc/SAMPLE/schema-list-key.yml
    ```

3. get  
    -> `/initial-data/SAMPLE/running-state.xml`

4. get-confg  
    -> `/initial-data/SAMPLE/running.xml`

5. edit docker-compose.yml

6. emulation start  
    ```bash
    ./emulation-start.sh
    ```

## License
see [LICENSE.txt](./LICENSE.txt)