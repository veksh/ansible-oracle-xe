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

Steps to create "orepl-xe" on orepl-xe-vm
=========================================

Somewhat site-specific

- create/clone VM for oracle db (on cageX)
    - 1-2 cpus, 2-4 GB (XE uses 1 cpu and 1 GB)
    - 2nd net card in srv-oracle
    - sys: on usual app.sys
    - apps: on apps.data, 20G for ora soft + system + data
- add to m0 inventory.cfg

        [all-m0]
        orepl-xe-vm   ansible_ssh_host=orepl-xe-vm.example-domain.com
        # ...
        [oracle-xe-servers]
        orepl-xe-vm

- add to site.yaml playbook

        - hosts: oracle-xe-servers
          become: true
          roles:
            - oracle-xe-server
          tags:
            - oracle-xe

- create `host_vars/orepl-xe-vm.yaml` or dir with host vars

        iface_configs:
          - iface: eth1
            name: orepl-xe.example-domain.com
            ip_cidr: 10.0.53.20/24

        extra_system_groups:
          - dba

        extra_system_users:
          oracle: {group: "dba", groups: "trusted", desc: "oracle user"}

        lvm_groups_dict:
          apps:
            pvs: /dev/sdb
            path: /u01/app/oracle
            owner: oracle
            group: dba
            mode: ug+rwx,o+rx
            def_fs: xfs
            def_opts: nosuid,noexec,nodev
            def_owner: oracle
            def_group: dba
            def_mode: ug+rwx,o=rx
            lvs:
              # not "soft" at "product" but "/": oracle install scripts check for free space in /u01/app
              ora-apps:  {size:  2G, path: "/u01/app/oracle", opts: "nodev"}
              ora-diag:  {size:  1G, path: "diag"}
              ora-data:  {size: 20G, path: "oradata", mode: "u=rwx,g=rx,o-rwx"}

- conf it with hostconf; change root password

        ansible-playbook site.yaml -l orepl-xe-vm --tags hostconf --diff

- create `host_vars/orepl-xe-vm/oracle.yaml` and pass vault, or add directly to host_vars

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
