# Artifact Demonstration Wizard Documents

## Content

This document covers

- [ADW Configuration](#adw-configuration)
  - [Configuration Metadata](#configuration-metadata)
  - [Define Commands](#define-commands)
- [Command-line Ssage](#command-line-usage)
  - [Project Control Plane](#project-control-plane)
  - [Self-defined Predicates](#self-defined-predicates)
- [Script programming guideline](#script-programming-guideline)
- [Concurrency and failure model](#concurrency-and-failure-model)

## ADW Configuration

`adw.yaml` is designed to be a document by itself, and thus must be highly readable. This is also why ADW chooses YAML instead of JSON for configuration.

Below is a completed example. This document will walk through it. If you know nothing about YAML, don't worry. Just copy the example below and substitute whatever names and commands you want :)

```yaml
---
adw_meta:
  pred:
    - init:
        help: Initialize environment.
    - build:
        is_exclusive: true
        help: Build uFS and/or related benchmark.
    - run:
        pass_unmatched_args: true
        help: Run experiments.
    - plot:
        help: Collect and plot data.
  env: # optional
    - SSD_NAME: "nvme1n1"
    - SSD_PICE_ADDR: "0000:c6:00.0"
    - CFS_ROOT_DIR: "${ADW_PROJ_ROOT_DIR}"
    - SPDK_SRC_DIR: "${CFS_ROOT_DIR}/cfs/lib/spdk"
    - CFS_MAIN_BIN_NAME: "${CFS_ROOT_DIR}/cfs/build/fsMain"
    - SCRIPT_DIR: "${ADW_PROJ_ROOT_DIR}/scripts"
adw_cmds:
  init: scripts/init-after-reboot.sh
  build:
    microbench:
      ufsnj: |
        cd $ADW_PROJ_ROOT_DIR/cfs
        mkdir -p build; cd build
        cmake -DCFS_JOURNAL_TYPE=NO_JOURNAL ..
        make -j $(nproc)
        cd $ADW_PROJ_ROOT_DIR/cfs_bench
        mkdir -p build; cd build
        make -j $(nproc)
      ufs: |
        cd $ADW_PROJ_ROOT_DIR/cfs
        mkdir -p build; cd build
        cmake ..
        make -j $(nproc)
        cd $ADW_PROJ_ROOT_DIR/cfs_bench
        mkdir -p build; cd build
        make -j $(nproc)
      ext4nj: "ADW_ALWAYS_DONE"
      ext4: "ADW_ALWAYS_DONE"
    varmail:
      ufs: $SCRIPT_DIR/build-filebench.sh varmail ufs
      ext4: $SCRIPT_DIR/build-filebench.sh varmail ext4
    loadmng: $SCRIPT_DIR/build-loadmng.sh
    leveldb:
      ufs: $SCRIPT_DIR/build-leveldb.sh ufs
      ext4: $SCRIPT_DIR/build-leveldb.sh ext4
  run:
    microbench:
      ufsnj: |
        data_dir=$(adw_mk_data_dir)
        sudo -E python3 $SCRIPT_DIR/ufs_microbench_suite.py --fs ufs --numapp=10 --single "${@:2}"
        mv log_* $data_dir
      ufs:  |
        data_dir=$(adw_mk_data_dir)
        sudo -E python3 $SCRIPT_DIR/ufs_microbench_suite.py --fs ufs --numapp=10 "${@:2}"
        mv log_* $data_dir
    varmail:
      ufs: $SCRIPT_DIR/run-filebench.sh varmail ufs
      ext4: $SCRIPT_DIR/run-filebench.sh varmail ext4
    loadmng:
      calloc: $SCRIPT_DIR/run-loadmng.sh callc
      dynamic: $SCRIPT_DIR/run-loadmng.sh dynamic
    leveldb:
      ufs:
        ycsb-a: $SCRIPT_DIR/run-leveldb.sh ycsb-a ufs
        ycsb-b: $SCRIPT_DIR/run-leveldb.sh ycsb-b ufs
        ycsb-c: $SCRIPT_DIR/run-leveldb.sh ycsb-c ufs
      ext4:
        ycsb-a: $SCRIPT_DIR/run-leveldb.sh ycsb-a ext4
        ycsb-b: $SCRIPT_DIR/run-leveldb.sh ycsb-b ext4
        ycsb-c: $SCRIPT_DIR/run-leveldb.sh ycsb-c ext4
  plot:
    microbench:
      "single: ufsnj, ext4nj": $SCRIPT_DIR/plot-microbench.sh single
      "multi: ufs, ext4": $SCRIPT_DIR/plot-microbench.sh multi
    varmail: $SCRIPT_DIR/plot-filebench.sh varmail
    loadmng:
      calloc: $SCRIPT_DIR/plot-loadmng.sh callc
      dynamic: $SCRIPT_DIR/plot-loadmng.sh dynamic
    leveldb:
      "ycsb-a: ufs/ycsb-a, ext4/ycsb-a": $SCRIPT_DIR/plot-leveldb.sh ycsb-a
      "ycsb-b: ufs/ycsb-b, ext4/ycsb-b": $SCRIPT_DIR/plot-leveldb.sh ycsb-b
      "ycsb-c: ufs/ycsb-c, ext4/ycsb-c": $SCRIPT_DIR/plot-leveldb.sh ycsb-c
```

Also, assume the repository is structured as

```
+ cfs/
+ cfs_bench/
+ adw.yaml
+ scripts/
    +- ufs_microbench_suite.py
    +- build-filebench.sh
    +- build-loadmng.sh
    +- build-leveldb.sh
    +- run-filebench.sh
    ...
```

From the high level, `adw.yaml` consists of two mappings: `adw_meta` and `adw_cmds`. `adw_meta` contains information about predicates and environment variables; `adw_cmds` shows the details for hierarchical targets.

### Configuration Metadata

A valid `adw_meta` must include `pred` and could optionally include `env`. The element under `pred` is a sequence of predicates. This must be a sequence because predicate relationships are ordered. Each predicate is a mapping, which maps predicate name to a few attributes:

- `help`: Required. When ADW shows a help message, this string will be used.
- `is_exclusive`: Optional; default is `false`. If a predicate is set to be exclusive, one target executes this predicate will trash other targets' success under this predicate.
- `pass_unmatched_args`: Optional; default is `false`. If this is `true`, ADW allows additional command-line arguments other than the path from predicate to a leaf. ADW will consider the shell commands in the leaf as a script and the command-line arguments that are not consumed will be passed down as this script's command-line arguments, accessible by `$@`, `$1`, `$2`, etc.

More attributes might be added in the future if we find them useful. For now, these three already provide good flexibility.

```yaml
adw_meta:
  pred:
    - init:
        help: Initialize environment.
    - build:
        is_exclusive: true
        help: Build uFS and/or related benchmark.
    - run:
        pass_unmatched_args: true
        help: Run experiments.
    - plot:
        help: Collect and plot data.
  env:
    - SSD_NAME: "nvme1n1"
    - SSD_PICE_ADDR: "0000:c6:00.0"
    - CFS_ROOT_DIR: "${ADW_PROJ_ROOT_DIR}"
    - SPDK_SRC_DIR: "${CFS_ROOT_DIR}/cfs/lib/spdk"
    - CFS_MAIN_BIN_NAME: "${CFS_ROOT_DIR}/cfs/build/fsMain"
    - SCRIPT_DIR: "${ADW_PROJ_ROOT_DIR}/scripts"
```

One could also set what environments to set when executing commands of this project by `env`. This must also be a sequence because the order of variable declaration matters. Note that ADW by default guarantees some variables declared, so `env` here could refer to these variables, too. More details can be found [below](#script-programming-guideline).

### Define Commands

`adw_cmds` is the actual representation of a tree-like workflow model. Each path starts with a predicate and when going down, it ends at a leaf with a string representing the shell commands to use. For now, we only support `bash`. A valid predicate name or target name can only use letter, number, `-`, and `_`. Prefix `adw_` or its capitalization variants are reserved for ADW internal usage, so they are not allowed in any user-defined predicate or target name. In addition, predicate with name `proj` be shaded by ADW project control plane (see [this section](#command-line-usage) for more details), so it is not recommended, either.

In the example above, `init`, has no target under this predicate, so the predicate is a leaf itself. Here for brevity, we make this shell command to be the start of another script.

```yaml
adw_cmds:
  init: ${ADW_PROJ_ROOT_DIR}/scripts/init-after-reboot.sh
```

You could also directly put the commands in a leaf instead of starting another script:

```yaml
adw_cmds:
  build:
    microbench:
      ufs: |
        cd $ADW_PROJ_ROOT_DIR/cfs
        mkdir -p build; cd build
        cmake ..
        make -j $(nproc)
        cd $ADW_PROJ_ROOT_DIR/cfs_bench
        mkdir -p build; cd build
        make -j $(nproc)
```

Since only a leaf contains shell commands, all dependency enforcement is transferred into requirements on one leaf or all leaves under a subtree. The dependency enforcement follows the rules below:

Predicates are in a linear order. Suppose predicate p1 is right ahead of p2. For a leaf `x` with path `p2/[PREFIX1]/x` where `[PREFIX1] = a/b/c/..`:

- If `p1/[PREFIX1]/x` exists and is a leaf, then it is considered as the dependency of `p2/[PREFIX]/X`.
- If `p1/[PREFIX1]/x` exists but is not a leaf, then all leaves under the subtree `p1/[PREFIX1]/x/` are considered as the dependencies
- If `p1/[PREFIX1]/x` doesn't exist, then find a path `p1/[PREFIX2]/y` where `y` is a leaf and `[PREFIX2]/y` is a prefix of `[PREFIX1]`. It should be easy to prove the existence and uniqueness of `p1/[PREFIX2]/y`. `p1/[PREFIX2]/y` is considered as the dependency of `p2/[PREFIX1]/x`.

If a leaf `y` is considered as one of the dependencies of `x`, then before executing commands in `x`, one must have `y`'s commands executed successfully. ADW will check the return status of `y`'s commands and only zero is considered as "successful".

In the example above:

- `run/microbench/ufs` requires `build/microbench/ufs`
- `plot/varmail` requires `run/varmail/ufs` and `run/varmail/ext4`
- `run/loadmng/dynamic` requires `build/loadmng`

There is one special command called `ADW_ALWAYS_DONE`: this means that the dependency enforcement system should always consider this command has been executed. For example, when benchmarking on ext4, we don't really need to build ext4 codebase. This basically marks this step "skipped".

```yaml
adw_cmds:
  build:
    microbench:
      ext4: "ADW_ALWAYS_DONE"
```

However, this special command should be used with caution because the dependency is a chain model in ADW and for predicates with the order "p1-p2-p3", p3 only requires p2 but not p1. If a target under p2 uses `ADW_ALWAYS_DONE`, there is no guarantee that this target has done "p1". In the example above, running `build/microbench/ext4` doesn't guarantee "init" has been done.

For more advanced usage, one could declare a new target with customized dependencies by a string formatted as `[NEW_TARGET_NAME]: DEPS` where `DEPS` is a comma-separated list of dependency names in a path-like format.

```yaml
adw_cmds:
  plot:
    leveldb:
      "ycsb-a: ufs/ycsb-a, ext4/ycsb-a": $SCRIPT_DIR/plot-leveldb.sh ycsb-a
      "ycsb-b: ufs/ycsb-b, ext4/ycsb-b": $SCRIPT_DIR/plot-leveldb.sh ycsb-b
      "ycsb-c: ufs/ycsb-c, ext4/ycsb-c": $SCRIPT_DIR/plot-leveldb.sh ycsb-c
```

This example means `adw plot leveldb ycsb-a` requires `run/leveldb/ufs/ycsb-a` and `run/leveldb/ext4/ycsb-a`. Note the dependencies can only be within the current subtree of the previous predicate (e.g. `run/leveldb/`) and cannot refer to higher-level i.e. `../` is not allowed. The customized dependency syntax should be used only when necessary, as it hurts the readability of `adw.yaml`.

## Command-line Usage

```console
$ adw
Usage: adw <COMMAND> [...]

COMMAND:
  proj <SUBCOMMAND>:    Manage ADW project.
  <PREDICATE>:  Execute self-defined predicates.

SUBCOMMAND:
  init [-f]:    Initialize a project for ADW; force reinitialization if `-f` is
                provided.
  load:         Load the current project; will reload if already.
  log [--less|--vim]:   Show the execution history and their status of the
                current project (on a pager if specified).
  list:         List all projects managed by ADW.
  add:          Add the current project to ADW global project list.
  remove <NAME>:        Remove the project specified by NAME from ADW global
                project list.
  global <-u|NAME>:     Set a project specified by NAME to be globally
                accessible; do unset instead if `-u` is set.
  cleanup:      Remove nonexisting projects from the list.
```

`adw`'s behavior depends on the first argument. `proj` is a reserved word for ADW's project control plane. Otherwise, it must be a predicate.

### Project Control Plane

To begin with, on the top-level directory, initialize the project for ADW:

```console
$ adw proj init
ADW: Init project uFS successfully
```

This will generate `.adw` and `ADW_DATA` directories. You may want to put these two directories to `.gitignore`.

Then load `adw.yaml`:

```console
$ adw proj load
ADW: Load project uFS successfully
```

Now if you try `adw`, you should see the help message in `adw.yaml` also shows up. Note in the latest version, adw can do such `adw proj load` automatically the first time trying to execute a predicate.

```console
$ adw
Usage: adw <COMMAND> [...]

COMMAND:
  proj <SUBCOMMAND>:    Manage ADW project.
  <PREDICATE>:  Execute self-defined predicates.

SUBCOMMAND:
  init [-f]:    Initialize a project for ADW; force reinitialization if `-f` is
                provided.
  load:         Load the current project; will reload if already.
  log [--less|--vim]:   Show the execution history and their status of the
                current project (on a pager if specified).
  list:         List all projects managed by ADW.
  add:          Add the current project to ADW global project list.
  remove <NAME>:        Remove the project specified by NAME from ADW global
                project list.
  global <-u|NAME>:     Set a project specified by NAME to be globally
                accessible; do unset instead if `-u` is set.
  cleanup:      Remove nonexisting projects from the list.

PREDICATE:
  init:         Initialize environment.
  build:        Build uFS and/or related benchmark.
  run:          Run experiments.
  plot:         Collect and plot data.
```

You could also see the execution log of the current project. The log includes the timestamps, duration, commit id, and exit status. As a note, ADW does expect that users may checkout different git branches during the experiment, so if the commit id changes during the experiments, both start commit id and finish commit id will show up in the log.

```console
$ adw proj log # you could use `--less` or `--vim` to choose pager
Time:   2021-09-02 17:38:22 -> 2021-09-02 17:38:22 [0s]
Commit: 82a016f
Status: 0
Command: build leveldb ext4

Time:   2021-09-02 17:38:16 -> 2021-09-02 17:38:17 [1s]
Commit: 82a016f
Status: 0
Command: run leveldb ufs ycsb-a
# ...
```

That's it! These are three key subcommands you should know. The rest subcommands are nothing fancier than some sugar.

ADW provides a tiny multi-project management system. You could save your recent projects in ADW:

```console
# at the top-level directory of uFS
$ adw proj add # add the current project
ADW: Add project uFS successfully
$ adw proj list # you should see uFS is listed
         uFS -> /abs/path/to/uFS
$ adw proj remove uFS
ADW: Remove project uFS successfully
$ adw proj list # empty output (no project)
```

By default, ADW only reads `.adw` in the current working directory. To enable the flexibility of running from any location, you could set a project globally accessible (pretty like `pyenv global`):

```console
$ adw proj add
ADW: Add project uFS successfully
$ adw proj global uFS
$ cd some/random/path
$ adw # now you can still see expected predicates are from uFS
Usage: adw <COMMAND> [...]

COMMAND:
  proj <SUBCOMMAND>:    Manage ADW project.
  <PREDICATE>:  Execute self-defined predicates.

SUBCOMMAND:
  init [-f]:    Initialize a project for ADW; force reinitialization if `-f` is
                provided.
  load:         Load the current project; will reload if already.
  log [--less|--vim]:   Show the execution history and their status of the
                current project (on a pager if specified).
  list:         List all projects managed by ADW.
  add:          Add the current project to ADW global project list.
  remove <NAME>:        Remove the project specified by NAME from ADW global
                project list.
  global <-u|NAME>:     Set a project specified by NAME to be globally
                accessible; do unset instead if `-u` is set.
  cleanup:      Remove nonexisting projects from the list.

PREDICATE:
  init:         Initialize environment.
  build:        Build uFS and/or related benchmark.
  run:          Run experiments.
  plot:         Collect and plot data.
```

### Self-defined Predicates

A valid ADW command should correspond to a path from the predicate to a leaf. For example

```bash
adw run leveldb ufs ycsb-a
```

This will then invoke the shell commands specified by `run/leveldb/ufs/ycsb-a` in `adw.yaml`. If a predicate has its `pass_unmatched_args` set to `true` in `adw.yaml`, ADW will allow additional command-line arguments and pass them to the shell commands.

```bash
adw run leveldb ufs ycsb-a --duration 20 # "--duration 20" will be passed down
```

## Script Programming Guideline

Users need to provide shell commands for each leaf. Here is a programming guideline for these commands and all scripts called by them.

ADW guarantees the declaration of these environment variables:

- `ADW_PROJ_ROOT_DIR`: the absolute path to the top-level directory of the current project.
- `ADW_PROJ_DATA_DIR`: the relative path of the data directory to `$ADW_PROJ_ROOT_DIR` (explained below). Default is `ADW_DATA`.
- `ADW_LIB`: the absolute path to ADW library.

`ADW_PROJ_ROOT_DIR` is used as an anchor. If your script A wants to refer to another script B, we encourage to code B's path as `$ADW_PROJ_ROOT_DIR/relative/path/to/B`.

ADW provides a library that contains some shell functions we found useful. To use them, try `source $ADW_LIB` in your shell scripts. You can find the details of these functions by `cat $ADW_LIB`, and the most important one is `adw_mk_data_dir`: This function provides a data management system with versioning.

```console
$ source $ADW_LIB
$ data_dir=$(adw_mk_data_dir NAME /path/to/data) # the path created by adw_mk_data_dir is in $data_dir
$ bash do_some_work.sh --output-dir $data_dir # use $data_dir as the directory to save experiment output
$ ls /path/to/data
DATA_NAME_82a016f_21-09-04-12-33-52    DATA_NAME_latest
$ ls ADW_DATA # $ADW_PROJ_DATA_DIR default is ADW_DATA
DATA_NAME
```

The data directory created by `adw_mk_data_dir` will contain commit id and timestamp. It also create a symbolic link suffix with "latest" to indicate which `DATA_NAME_*` is the latest one. This can be useful if you run the same experiment multiple times so there are multiple data directories `DATA_NAME_*` with timestamps. Instead of comparing timestamps to figure out which one is the latest, you could simply dereference the symbolic link `DATA_NAME_latest`. This turns out to be extremely friendly to some log parser scripts. Furthermore, the data directory referred by "latest" will also be symbolically linked under `$ADW_PROJ_ROOT_DIR/$ADW_PROJ_DATA_DIR`. This is just a sweeter sugar for log parser.

## Concurrency and Failure Model

ADW does not allow users to run multiple `adw` commands simultaneously. The current version of ADW has not implemented any locking mechanism yet, so the behavior will be undefined if multiple `adw` commands running concurrently. ADWs installed to different ADW_HOME would be safe to run concurrently as long as their project lists are disjointed.

Before executing commands of a leaf, ADW will trash this leaf's previous success signal (if exists). The new success signal will only be set when this time's execution succeeds. This ensures that if ADW gets killed in the middle of execution, this leaf's undefined states will be considered as "unsuccessful." ADW doesn't guarantee recovery if ADW-managed metadata gets corrupted. ADW-managed metadata includes all files under `$ADW_HOME` and `.adw` in every project.
