# Artifact Demonstration Wizard

Artifact Demonstration Wizard (ADW) is a framework to organize the experiment workflow of a project.

If any of the problems below had troubled you, you will probably like ADW:

- The codebase is supposed to be built with configuration A for experiment 1 and with configuration B for experiment 2. You just finished experiment 1. Then you start experiment 2 but you forget to rebuild the codebase with configuration B. In the best case, it produces some garbage outputs so you have to rerun it; in the worst case, you never realize this is garbage output...

- You have several experiments to run and you start one of them. The experiment takes hours, so you decide to switch to YouTube when waiting (it's fully justified, right?). Hours later, you pause YouTube and want to check out the experiment results, but you forget which experiment you started hours ago...

- You run an experiment several times and each generates a directory for its output logs. Then you have a set of log directories, but every time when you (or likely, your log parser script) want to take a look, you have to figure out which one is the latest.

- You run an experiment several times on a few branches. A week later, you track down a problem and want to see if it presented in a branch's log earlier. However, you have no way to tell which log was from which branch's code. Literally, no way.

Typically, people write ad hoc scripts to tackle the problems above (or just live with them, pretending they won't happen again). ADW is designed to organize the workflow and do the dirty work for you.

## Install

To install `adw`:

```bash
./install.sh
```

This will install ADW to `~/.adwarts`.

To uninstall:

```bash
./install.sh -u
```

OR you could try single-line install command, which even does `git clone` for you:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chenhao-ye/adw/main/install.sh)" install.sh -p
```

and single-line uninstall command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chenhao-ye/adw/main/install.sh)" install.sh -u
```

Note you may need to restart the shell to load the new environment variables.

## Overview

ADW uses a workflow model named "predicates and hierarchical targets." Let's talk about it with a quick example. Suppose you have developed a novel user-level filesystem called uFS. Now you want to automate the workflow of compiling and benchmarking uFS and ext4 against LevelDB workload. The workflow could be divided into three steps: `init`, `build`, and `run`. We call these steps "predicates." The workflow of this experiment could be modeled as:

- For predicate `init`, all you want is some system-wide setting; it doesn't matter whether it is initialized for uFS or ext4.
- For `build`, you want to specify whether build with uFS's APIs or ext4's APIs
- For `run`, you want to specify not only uFS or ext4 but also which input traces to feed (suppose we have three traces collected from YCSB, named as `ycsb-a` to `ycsb-c`)

This model gives us the tree-like structure below. Every node on this tree is either a predicate (`init`, `build`, `run`) or a target (e.g. `leveldb`, `ufs`, `ycsb-c`, etc). Predicates are in a linear relationship with each other (e.g. `init` is before `build`), and targets are in a hierarchical relationship (e.g. `ufs` is under `leveldb`).

```
+- init
|
+- build
|    +- leveldb
|         +- ufs
|         +- ext4
|
+- run
     +- leveldb
          +- ufs
          |    +- ycsb-a
          |    +- ycsb-b
          |    +- ycsb-c
          +- ext4
               +- ycsb-a
               +- ycsb-b
               +- ycsb-c
```

In addition, you want to enforce these constraints:

- One must do `init` before any `build`.
- Before running LevelDB for uFS (regardless which trace), one must compile LevelDB with uFS's APIs first. Same for ext4.

When using ADW, the user provides a configuration file `adw.yaml`, located at the top-level directory of the uFS codebase (just like `Dockerfile` and `Makefile`). `adw.yaml` describes the tree-like workflow above and specifies what shell commands to run for each path from a predicate to a leaf (e.g. `init`, `build/leveldb/ufs`, `run/leveldb/ufs/ycsb-a`). The detailed tutorials of `adw.yaml` can be found [here](docs/README.md).

ADW will load `adw.yaml` and enforce the constraints for you. For example, if you `build` without `init`:

```console
$ adw build leveldb ufs
ADW: Execution rejected: build/leveldb/ufs
  Dependencies unsatisfied:
    - init
```

Or you `run` with a wrong target built before.

```console
$ adw init
$ adw build leveldb ufs
$ adw run leveldb ext4 ycsb-a
ADW: Execution rejected: run/leveldb/ext4/ycsb-a
  Dependencies unsatisfied:
    - build/leveldb/ext4
```

The dependency enforcement also comes with a user-friendly help message for "what is expected" if an incorrect path is provided:

```console
$ adw run leveldb
Usage: adw run leveldb {ext4|ufs} [...]

$ adw run leveldb ufs
Usage: adw run leveldb ufs {ycsb-a|ycsb-b|ycsb-c} [...]

$ adw run leveldb wrong_target
Usage: adw run leveldb {ext4|ufs} [...]
```

For fancier usage, you could pass additional command-line arguments to the script:

```bash
adw run leveldb ufs ycsb-a --duration 20
```

ADW will recognize `run/leveldb/ufs/ycsb-a` reaching a leaf and then pass the rest of command-line arguments to the script indicated by `run/leveldb/ufs/ycsb-a`.

For more advanced usage, you could set predicate `build` "exclusive": the successful execution of one leaf under `build` will invalidate other success under `build`. For example, `build/leveldb/ufs` compiles LevelDB with uFS's APIs. Later if you execute `build/leveldb/ext4`, which recompiles LevelDB with ext4's APIs, the previous compilation's binary will be overwritten and the success of `build/leveldb/ufs` should be invalidated:

```console
$ adw build leveldb ufs
$ adw run leveldb ufs ycsb-a # OK
$ adw build leveldb ext4     # Exclusive predicate `build` invalidates build/leveldb/ufs
$ adw run leveldb ufs ycsb-a # NOT OK
ADW: Execution rejected: run/leveldb/ufs/ycsb-a
  Dependencies unsatisfied:
    - build/leveldb/ufs
```

All commands that pass dependencies enforcement will be logged. The log includes start time, finish time, duration, git commit id, and the command's exit code.

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

Time:   2021-09-02 17:38:10 -> 2021-09-02 17:38:10 [0s]
Commit: 82a016f
Status: 0
Command: build leveldb ufs

Time:   2021-09-02 17:38:04 -> 2021-09-02 17:38:04 [0s]
Commit: 82a016f
Status: 0
Command: run leveldb ufs ycsb-a --duration 20

Time:   2021-09-02 17:37:49 -> 2021-09-02 17:37:49 [0s]
Commit: 82a016f
Status: 0
Command: run leveldb ufs ycsb-a

Time:   2021-09-02 17:37:38 -> 2021-09-02 17:37:38 [0s]
Commit: 82a016f
Status: 0
Command: build leveldb ufs

Time:   2021-09-02 17:37:27 -> 2021-09-02 17:37:27 [0s]
Commit: 82a016f
Status: 0
Command: init
```

ADW also has other fancy functionality e.g. a library for data management. Please refer to the [document](docs/README.md) for more information.

## Motivation

ADW is abstracted from [uFS](https://github.com/WiscADSL/uFS) (yes, the example above is not fictional; uFS is real) submission of artifact evaluation to SOSP 2021. We would like to automate the experiments to make reviewers' jobs easier. When working on the automation, we encountered a few tricky problems:

1. We have many experiments to run, so we have to make a long list to organize the logical connections between experiments and what configuration to use. This eventually became the prototype of `adw.yaml`. `adw.yaml` is designed to show the logical connections between experiments clearly. Anyone new to the project is expected to read `adw.yaml` to get the high-level pictures of experiments easily.

2. We have to write a lot of redundant code to sanity check command-line arguments to make things as fool-proof as possible. This directly motivates us to build ADW, which reads a configuration and do sanity check for you. Moreover, it's very nature to see the dependency relationship between steps, so we add dependency enforcement into ADW.

3. Our experiments require some environment variables set. This means that every time starting an `tmux` session, one must run some `source`. Sometime we forgot, and the script crashed minutes later. Putting these environments into `.bashrc` could work, but it's not clean. We realize that we want a centralized entry point for all experiments, and this entry point takes care of loading the environment variables. This entry point later became the prototype of `adw` command, and we allow user to declare environment variables in `adw.yaml`.

4. We want to optimize for data management and logging. Experiments produce a lot of data, and we must give a unique label for each one. We then wrapped a `mkdir` into a new directory creation shell function with a timestamp in the directory name. Later we found commit id is also useful, so we add it too. We also find shell's `history` doesn't contain enough information (e.g. we really want to know how long an experiment takes...), so we wrote one ourselves.

5. We have a lot of scripts written, and we want a uniform system to glue them together. Often, a script A may want to run another script B. How to find B becomes tricky. One could surely hard-code every absolute path, so A always knows exact location of B. This could work well, except you would be cursed by a later maintainer. Alternatively, A could use a relative path, but this implicitly assumes the current working directory when A is running. Eventually, we decide to declare an environment variable for the absolute path of the codebase's top directory, and A could find B as long as A knows B's location relative to the codebase's top directory. How to enforce this environment variable declared is handled by problem 3.
