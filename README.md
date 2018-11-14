Oracle XE Server install
========================

Role to install free Oracle XE database on host, create and tune DB and OS settings.
I've tried to remove dependenices on other custom roles and environment, but role
is still a bit site-specific and requires a bit of review and customization to be
actually useful.

Features: what does that role do
================================
- Tune OS for oracle installation: create 2GB of swap if not yet, set kernel params etc
- Install Oracle XE software, perform DB intialization
- Configure DB, set it to autostart, fix init script a bit
- Configure listener and tnsnames.ora (for dblinks or connections to other DBs)
- Create cron task to trim DB and listener logs
- Perform DB tuning, trim unnesessary components, e.g.
    - allow system TS to autoextend
    - re-create redo logs in data dir with custom size, add 3rd log file
    - modify init params: turn off recycle bin, turn on audit, etc
    - drop APEX and example schemes from db, create missed DBSNMP user
    - disable password expiration
    - re-schedule nightly maintenance jobs to custom window
    - turn on DB audit on interesting events, create DB audit trail auto-purge task
    - set statistic history retention period
- Create required db objects
    - roles, with optional grants to them
    - profiles, with specified limits
    - users, with passwords, profiles, grants and quoutas assigned to them
    - database links connected to specified remote DBs

Those steps produce clean self-maintained instance of RDBMS with some XE shortcomings
fixed (like default password expiration policy of 120 days, APEX and example schemas
etc).

Requirements
============
- Oracle XE rpms accessible by package manager
- Enough space in `/u01/app/oracle` for software (500M) and oracle data (2G for starter DB),
  optionally subdivided into logical volumes.
- Usual Oracle XE system requirements (see below for VM config)
- Currently tested on SLES, could work on other distributions with some modifications.

Example steps to install XE in VM
=================================

- add to inventory

        # ...
        [oracle-xe-servers]
        orepl-xe-vm   ansible_ssh_host=orepl-xe-vm.example-domain.com

- add to site.yaml playbook

        - hosts: oracle-xe-servers
          become: true
          roles:
            - oracle-xe-server
          tags:
            - oracle-xe

- create `host_vars/orepl-xe-vm.yaml` 

        ## oracle vars
        oracle_listener_iface: eth1
        oracle_host_name: "orepl-xe.example-domain.com"
        oracle_external_alias: "orepl-xe"
        oracle_db_clients:
          - 10.1.11.0/24

        # for tnsnames.ora; usually in group vars
        oracle_servers:
          orepl-m0: {host: 'orepl-xe.example-domain.com', service: 'XE'}

        # passwords better be in vault and skipped from here
        # oracle_pass_vault: {sys: <pass>, ...}
        oracle_users:
          some_user:
            password: "{{ lookup('password', 'creds/some_user' + oracle_passgen_opts) }}"
            roles:
              - appholder
            quotas:
              users: 2048M
            grants:
              create session:
        # better keep it in vault too
        oracle_password_sys: "{{ lookup('password', 'creds/sys' + oracle_passgen_opts) }}"

- create db and objects

        ansible-playbook site.yaml -l orepl-xe-vm --tags oracle-xe --diff

- ext: add to backup and monitoring
- ext: add to tnsnames
