#!/usr/bin/env python3

import sys
import os
import subprocess
import platform
import argparse
import functools
import yaml
import re
import urllib.parse


SDK_CFG_YAML = 'test-cfg.yaml'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
class GitWrapper:

    #---------------------------------------------------------------------------
    @classmethod
    def run_command(cls, cmd: str, params: list, cwd=None):
        print(f'{cmd} {" ".join(params)}')
        # check=True: raise CalledProcessError exception on failure
        ret = subprocess.run([ cmd ] + params, cwd=cwd)
        return ret.returncode

    #---------------------------------------------------------------------------
    @classmethod
    def run_git(cls, params: list, cwd=None):
        return cls.run_command(
            cmd    = 'git',
            params = params,
            cwd    = cwd)

    #---------------------------------------------------------------------------
    def __init__(self, server: str, protocol: str = 'ssh', port: int = None):
        self.protocol = protocol
        self.server = server
        self.port = port if port is not None \
                    else 7999 if protocol == "ssh" \
                    else None


    #---------------------------------------------------------------------------
    def get_repo_url(self, repo: str) -> str:

        credentials = "git" if self.protocol == 'ssh' \
                      else self.user+':'+urllib.parse.quote(self.password, safe='') if self.protocol == 'https' \
                      else None

        return self.protocol + '://' + \
               ( f'{credentials}@' if credentials else '' ) + \
               self.server + \
               ( f':{self.port}' if self.port else '' ) + \
               '/' + \
               ( 'scm/' if self.protocol == 'https' else '') +  \
               repo


    #---------------------------------------------------------------------------
    def branch_exists(self, repo: str, branch: str) -> bool:
        ret = self.run_git([
                'ls-remote',
                '--exit-code',
                '--heads',
                self.get_repo_url(repo),
                branch
            ])
        return (ret == 0)


    #---------------------------------------------------------------------------
    def clone(self: object, repo: str, branch: str, folder: str):
        ret = self.run_git([
            'clone',
            '--jobs', '4',
            '--recursive',
            '--branch', branch,
            self.get_repo_url(repo),
            folder
        ])
        if ret != 0:
            raise AssertionError(f'git clone operation failed')

    #---------------------------------------------------------------------------
    @classmethod
    def show_submodule_versions(cls, cwd=None):
        ret = cls.run_git([
            'submodule',
            'status',
            '--recursive'
        ], cwd=cwd)
        if ret != 0:
            raise AssertionError(f'git submodule check failed')


#-------------------------------------------------------------------------------
def create_git_wrapper(ci_system):

    if ci_system == "bamboo":
        git = GitWrapper(server='bitbucket.app.hensoldt.net',
                         protocol='https')
        assert 'bamboo_GIT_HTTPS_USER' in os.environ
        git.user = os.getenv('bamboo_GIT_HTTPS_USER')
        assert 'bamboo_GIT_HTTPS_SECRET_TOKEN' in os.environ
        git.password = os.getenv('bamboo_GIT_HTTPS_SECRET_TOKEN')
        return git

    elif ci_system == "jenkins":
        git = GitWrapper(server='bitbucket.app.hensoldt.net',
                         protocol='https')
        return git

    elif (ci_system == "local") or (ci_system is None):
        # ssh with ssh-agent
        git = GitWrapper(server='vm-bb-hensoldt',
                         protocol='ssh',
                         port=7999)
        return git

    else:
        pass

    raise AssertionError(f'unknown CI system: {args.ci_system}')


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
class SystemCtx:
    FLAG_BUILD      = 1 << 0
    FLAG_TEST       = 1 << 1
    # For demos included in the SDK package, CI will checkout them from their
    # default repo or use that the SDK package contains at the given location.
    FLAG_SDK_DEMO   = 1 << 2

    #
    #     String      name       // Name of the system to build.
    #     Map         platforms  // List of supported platforms.
    #     Map         params     // Parameters
    #
    #     //--------------------------------------------------------------------------
    #     public SystemCtx(name, platforms, params)
    #     {
    #         this.name = name
    #         this.platforms = platforms
    #         this.params = params ?: [:]
    #
    #         // ensure proper defaults exists
    #         this.params.putIfAbsent('flags', 0)
    #         this.params.putIfAbsent('testScript', name + '.py')
    #         this.params.putIfAbsent('testSystem', 'ss/' + name)

    #---------------------------------------------------------------------------
    @classmethod
    def isDemo(cls, ctx):

        ret = (0 != (ctx['params']['flags'] & cls.FLAG_SDK_DEMO))

        # Check demo name against the well-known list. Adding new demos to the
        # SDK package could have side effects that should be well understood.
        if ret:
            assert ctx['name'] in [ 'demo_hello_world',
                                    'demo_iot_app',
                                    'demo_iot_app_imx6',
                                    'demo_iot_app_rpi3',
                                    'demo_network_filter',
                                    'demo_tls_api' ]

        return ret


#-------------------------------------------------------------------------------
def make_SystemCtx(name, platforms, params):
    ctx = {
        'name': name,
        'platforms': platforms,
        'params': {
            'flags': 0,
            'testScript': f'{name}.py',
            'testSystem': f'ss/{name}',
        }
    }

    if params: ctx['params'].update(params)

    return ctx


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
class YAML_Config_Parser:

    #---------------------------------------------------------------------------
    @classmethod
    def parse_flags(cls, arg):
        if not arg:
            return 0

        if isinstance(arg, list):
            return functools.reduce(lambda v,s: v|cls.parse_flags(s), arg, 0)

        if isinstance(arg, str):
            flags = {
                'BUILD':    SystemCtx.FLAG_BUILD,
                'TEST':     SystemCtx.FLAG_TEST,
                'SDK_DEMO': SystemCtx.FLAG_SDK_DEMO,
            }.get(arg.upper())
            if not flags:
                raise AssertionError(f'unknown flag: {arg}')
            return flags

        raise AssertionError(f'unsupported flag argument {arg}')


    #---------------------------------------------------------------------------
    @classmethod
    def parse_params(cls, arg):
        if not arg:
            return []

        if isinstance(arg, list):
            return [cls.parse_params(e) for e in arg]

        if isinstance(arg, str):
            return [ arg ]

        raise AssertionError(f'unsupported parameter argument {arg}')

        return params

    #---------------------------------------------------------------------------
    @classmethod
    def parse_platform_params(cls, arg):
        params = {}

        if not arg:
            pass

        elif isinstance(arg, list):
            for e in arg:
                params.update(cls.parse_platform_params(e))

        elif isinstance(arg, dict):
            pass
            # for (e in arg) {
            #     switch(e.key) {
            #         case 'addFlags':
            #             params.putAt(e.key, cls.parse_flags(e.value))
            #             break
            #         case 'buildParams':
            #         case 'testParams':
            #             params.putAt(e.key, cls.parse_params(e.value))
            #             break
            #         default:
            #             error('unknown platform attribute: ' + e.key)
            #     }
            # }

        else:
            raise AssertionError(f'unsupported platform parameter argument: {arg}')

        return params


    #---------------------------------------------------------------------------
    @classmethod
    def parse_platforms(cls, arg):
        platforms = {}

        if not arg:
            pass

        elif isinstance(arg, list):
            for e in arg:
                platforms.update(cls.parse_platforms(e))

        elif isinstance(arg, dict):
            for k,v in arg.items():
                platforms[k] = cls.parse_platform_params(v)

        elif isinstance(arg, str):
             platforms[arg] = {}

        else:
            raise AssertionError(f'unsupported platform argument: {arg}')

        return platforms


    #-------------------------------------------------------------------------------
    @classmethod
    def process(yaml_cfg: dict):

        system_configs = []

        if not isinstance(yaml_cfg, dict):
            raise AssertionError(f'YAML file invalid: {yaml_cfg}')

        # test system names must be sane
        system_name_pattern = re.compile('^[a-zA-Z_][a-zA-Z0-9_\-]*$')

        # each list element is a dict with exactly one elements.
        for systemName, data in yaml_cfg.items():
            if not system_name_pattern.match(systemName):
                raise AssertionError('invalid test system name: {systemName}')

            if systemName in system_configs:
                raise AssertionError(f'duplicate test system: {systemName}')

            # Currently all items are maps, if we see a String here this likely
            # indicates a wrong indention. Any other type indicates something
            # is really broken.
            if not isinstance(data, dict):
                raise AssertionError(f'system "{systemName}" has invalid attribute: {attr}')

            platforms = {}
            params = { 'flags': 0}

            for attrName, data in data.items():

                if attrName == 'flags':
                    params[attrName] = cls.parse_flags(data)

                elif attrName == 'platforms':
                    platforms = cls.parse_platforms(data)

                elif attrName in ['testSystem', 'testScript']:
                    assert isinstance(data, str)
                    params[attrName] = data

                elif attrName in ['buildParams', 'testParams']:
                    params[attrName] = cls.parse_params(data)

                else:
                    raise AssertionError(f'system "{systemName}" has unsupported attribute: {attr}')

            ctx = make_SystemCtx(systemName, platforms, params)
            system_configs.append(ctx)

        return system_configs


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
class Config:

    #-------------------------------------------------------------------------------
    def __init__(self, filename: str):

        if not os.path.isfile(filename):
            raise FileNotFoundError(f'missing YAMl file: {filename}')

        self.filename = filename

        with open(filename, 'r') as f:
            ymal_cfg_dict = yaml.safe_load(f)
            self.systems = YAML_Config_Parser.parse(ymal_cfg_dict)


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Pick sources from generic branches if there is no specific branch.
def get_fallback_branches(branch, branches = ['integration', 'master']):

    if idx, b in enumerate(branches):
        if (b == branch):
            return branches[idx:]

    return [ branch ] + branches


#-------------------------------------------------------------------------------
def list_demo_repos(cfg: Config):
    for ctx in cfg.systems:
        name = ctx['name']
        params = ctx['params']
        if (0 != (params['flags'] & SystemCtx.FLAG_SDK_DEMO)):
            print(params['testSystem'])


#-------------------------------------------------------------------------------
def checkout_demo_repos(cfg: Config, branch: str):
    for ctx in cfg.systems:
        name = ctx['name']
        params = ctx['params']
        if (0 != (params['flags'] & SystemCtx.FLAG_SDK_DEMO)):
            repo = params['testSystem']
            path = os.path.join('src', 'demos', repo)
            print(f'ToDo: do_checkout ${demo_repo} ${branch} ${path}')




#-------------------------------------------------------------------------------
# get system source from repo
def get_system_sources(git, ctx, branch, folder):

    systemName = ctx['name']
    repo = ctx['params']['testSystem']

    branches = get_fallback_branches(branch)

    for b in branches:
        if git.branch_exists(repo, b):
            git.clone(repo, b, folder)
            ctx['params']['srcBranch'] = b
            ctx['params']['srcFolder'] = folder
            break
    else:
        raise AssertionError(f'could not find a branch for demo : {systemName}')


#-------------------------------------------------------------------------------
# get SDK and demo sources from repo
def get_sdk_package_sources(
    git: GitWrapper,
    branch: str,
    folder_sdk: str,
    folder_demos: str):

    # get the SDK
    git.clone('seos/sandbox', branch, folder_sdk)

    # process the config
    ymal_cfg_file = os.path.join(folder_sdk, SDK_CFG_YAML)
    cfg = Config(config_yaml_file)
    # get demos
    for ctx in cfg.systems:
        systemName = ctx['name']
        if SystemCtx.isDemo(ctx):
            # this sets 'srcFolder' and 'srcBranch'
            get_system_sources(git, ctx, branch, os.path.join(folder_demos, systemName))

    return cfg


#-------------------------------------------------------------------------------
def create_sdk_package(git: GitWrapper, branch: str, folder: str):

    OUT_PKG_DIR = 'pkg'

    folder_sdk = os.path.join(folder, 'sandbox')
    # This SDK package building scrip assumes it exists in a directory structure
    # like the one of seos_tests. The CI job must check out the demos according
    # to this layout, otherwise the script will fail. Rationale is, that we
    # we want SDK package in CI work like the developer friendly one where
    # the seos_tests repo is used.
    folder_demos = os.path.join(folder, 'demos')

    cfg = get_sdk_package_sources(git, branch, folder_sdk, folder_demos)

    # Jenkins CI overwritew the 'testSystem' parameter with the location, and
    # the system build/test job knows that for FLAG_SDK_DEMO it's a folder and
    # not a repo.
    #
    #   for ctx in cfg:
    #     ctx['params']['testSystem'] = os.path.join('demos', systemName)
    #
    # We don't really need this, as we store this in 'srcFolder'

    #--------------------------------------------------------
    # from here on there is a shell script
    #--------------------------------------------------------

    # ToDo: write to version info file
    GitWrapper.show_submodule_versions(cwd=folder_sdk)

#
#    BASIC_SANDBOX_EXCLUDES = [
#        # remove all astyle prepare scripts
#        'astyle_prepare_submodule.sh',
#        # remove internal files in the sandbox root folder
#        './build-sdk.sh',
#        './publish_doc.sh',
#        # remove CI files and test confguration
#        './jenkinsfile',
#        './bamboo-specs',
#        SDK_CFG_YAML,
#        # remove axivion scripts
#        './scripts/axivion',
#        './scripts/open_trentos_analysis_env.sh',
#        # remove unwanted repos
#        './sdk-pdfs',
#        './tools/kpt',
#        # remove all readme files except from os_core_api which shall be
#        # included in the doxygen documentation
#        './README.md',
#        './components/*/README.md',
#        './libs/*/README.md',
#        #./os_core_api/README.md # remove later after doxygen
#        './resources/README.md',
#        './resources/*/README.md',
#        './scripts/README.md',
#        './sdk-sel4-camkes/README.md',
#        './tools/*/README.md',
#        # remove unwanted resources
#        './resources/rpi4_sd_card',
#        './resources/scripts',
#        './resources/zcu102_sd_card',
#        # remove imx6_sd_card resources, requires special handling
#        './resources/imx6_sd_card',
#        # remove keystore_ram_fv test folder
#        './libs/os_keystore/os_keystore_ram_fv/keystore_ram_fv/test',
#    ]
#
#    #---------------------------------------------------------------------------
#    # Copy SDK sources using tar and filtering, this is faster and more flexibel
#    # than the cp command.
#    # NOTE: Use "--exclude-vcs" to exclude vcs directories since there seems to
#    # be a bug in tar when using "--exclude .gitmodules".
#    #---------------------------------------------------------------------------
#
#    # print_info "Copying SDK sources from ${SDK_SRC_DIR} to ${OUT_PKG_DIR}"
#
#    def copy_files_via_tar(src_dir, dst_dir, params):
#        # rsync would do the job nicely, but unfortunately it is not available
#        # in some environments
#        #
#        #   rsync -a \
#        #       --exclude='.git' \
#        #       --exclude='.gitmodules' \
#        #       --exclude='.gitignore' \
#        #       --exclude 'astyle_prepare_submodule.sh' \
#        #       ${src_dir}/ \
#        #       ${dst_dir}/
#        #
#        # so we (ab)use tar for this, which is faster than cp. And as side
#        # effect, from this solution we could easily derive a way to get
#        # everything into one archive - if we ever need this.
#        subprocess.run(
#            [ 'mkdir', '-p', dst_dir ],
#            check=True)
#
#        subprocess.run(
#            [ f'tar -c -C {src_dir} {" ".join(params)} ./ | tar -x -C {dst_dir}/' ],
#            shell=True, check=True)
#
#
#    copy_files_via_tar(SDK_SRC_DIR, OUT_PKG_DIR,
#        [
#            '--exclude-vcs',
#            '--no-wildcards-match-slash'
#        ] + [ ('--exclude', f) for f in BASIC_SANDBOX_EXCLUDES \
#              for x in y ]
#
#    #---------------------------------------------------------------------------
#    # Special handling for imx6 resources, some files are in a common folder in
#    # the resources repository and need to be copied to the specific platform
#    # folders.
#    #---------------------------------------------------------------------------
#    # print_info "Copying imx6 resources..."
#    for board in ['nitrogen6sx', 'sabre']:
#        for folder in [board, 'common']:
#            copy_files_via_tar(
#                os.path.join(SDK_SRC_DIR, 'resources', 'imx6_sd_card', folder),
#                os.path.join(OUT_PKG_DIR, 'resources', f'{board}_sd_card'))
#
#    #---------------------------------------------------------------------------
#    # next steps:
#    #   do_sdk_step build-tools
#    #   # collect demos after tool build to ensure there is no dependency
#    #   do_sdk_step collect-demos
#    #   # documentation build also covers demos
#    #   do_sdk_step build-docs
#    #   do_sdk_step build-package


#-------------------------------------------------------------------------------
def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        '-i', '--info',
        action='store_true')

    parser.add_argument(
        '-c', '--ci-system', # stored as ci_system
        metavar='<ci-system>')

    parser.add_argument(
        '-b', '--branch',
        metavar='<branch>')

    # The following option are not meant to be combined, because they implement
    # different use cases. There is nothing really blocking using them together,
    # if we support this we should do it in the order give at the comment line.
    group = parser.add_mutually_exclusive_group()

    group.add_argument(
        '-l', '--list-demo-repos', # stored as list_demo_repos
        nargs = '?',
        default = None, # set if argument is not given at all
        const = SDK_CFG_YAML, # set if no explicit parameter is given
        metavar='<cfg-file>',)

    group.add_argument(
        '-l', '--checkout-demo-repos', # stored as checkout_demo_repos
        nargs = '?',
        default = None, # set if argument is not given at all
        const = SDK_CFG_YAML, # set if no explicit parameter is given
        metavar='<cfg-file>',)

    group.add_argument(
        '-p', '--build-sdk-package', # stored as build_sdk_package
        action='store_true')

    return parser.parse_args()


#-------------------------------------------------------------------------------
def main():

    args = parse_args()

    branch = 'integration' if args.branch is None \
             else args.branch

    if args.info:
        print(f'Python: {platform.python_version()}')
        print(f'args: {args}')
        print(f'working dir: {os.getcwd()}')

    if args.list_demo_repos is not None:
        config_yaml_file = args.list_demo_repos
        cfg = Config(config_yaml_file)
        list_demo_repos(cfg)

    if args.checkout_demo_repos is not None:
        config_yaml_file = args.list_demo_repos
        cfg = Config(config_yaml_file)
        checkout_demo_repos(cfg, branch)

    if args.build_sdk_package:
        git = create_git_wrapper(args.ci_system)
        create_sdk_package(git, branch, 'src')

    print('nothing to do?')


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
if __name__ == "__main__":
    # execute only if run as a script
    main()
