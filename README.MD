Claude & Chatgpt have assisted with the creation of this module.   

Usage: 
add this repo as a flake input. 
```
    services.ola-ftdi = {
    enable = true;
    web = {
        enable = true;
        port = 9090;
        host = "0.0.0.0"; # expose on network
    };
    };
```

To develop, clone this repo and run:
```nix develop```
