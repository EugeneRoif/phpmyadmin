The certificate (Private Key is there by design - NOT to be used externally)

Very open by design.

This is NOT production grade as it is very "open".
```
┌───────────────────────────────────────────────────────────┐
│                                                           │
│                                                           │
│                                                           │
│   ┌─────────────────┐         ┌────────────────────┐      │
│   │                 │         │                    │      │
│   │   Terraform     ├────────►│  AWS API           │      │
│   │                 │         │                    │      │
│   └─────────────────┘         └─────┬──────────────┘      │
│                                     │                     │
│                                     │                     │
│                                     │                     │
│                                     │                     │
│                                     ▼                     │
│   ┌──────────────────┐       ┌────────────────────┐       │
│   │                  │       │                    │       │
│   │ Ansible          ├──────►│ Output - Servers   │       │
│   │                  │       │                    │       │
│   └──────────────────┘       └────────────────────┘       │
│                                                           │
│                                                           │
│                                                           │
│                                                           │
│                                                           │
└───────────────────────────────────────────────────────────┘
```
