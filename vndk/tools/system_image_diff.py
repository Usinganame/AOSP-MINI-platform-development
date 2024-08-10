#!/usr/bin/env python3
import argparse
import csv
import glob
import json
import os
import sys
HELP_MSG = '''
Diff between 2 builds
'''
VENDOR_PATH_MAP = {
    'vendor/google' : 'Google',
    'vendor/unbundled_google': 'Google',
    'vendor/verizon' : 'Verizon',
    'vendor/qcom' : 'Qualcomm',
    'vendor/tmobile' : 'TMobile',
    'vendor/mediatek' : 'Mediatek',
    'vendor/htc' : 'HTC',
    'vendor/realtek' : 'Realtek'
}
def _get_relative_out_path_from_root(out_path):
  system_path = os.path.normpath(os.path.join(out_path, 'system'))
  system_path_dirs = system_path.split(os.sep)
  out_index = system_path_dirs.index("out")
  return os.path.join(*system_path_dirs[out_index:])
def system_files(path):
  system_files = []
  system_prefix = os.path.join(path, 'system')
  system_prefix_len = len(system_prefix) + 1
  for root, dirs, files in os.walk(system_prefix, topdown=True):
    for file in files:
      if not os.path.islink(os.path.join(root, file)):
        system_files.append(os.path.join(root[system_prefix_len:], file))
  return system_files
def system_files_to_package_map(path):
  system_files_to_package_map = {}
  system_prefix = _get_relative_out_path_from_root(path)
  system_prefix_len = len(system_prefix) + 1
  with open(os.path.join(path, 'module-info.json')) as module_info_json:
    module_info = json.load(module_info_json)
    for module in module_info:
      installs = module_info[module]['installed']
      for install in installs:
        if install.startswith(system_prefix):
          system_file = install[system_prefix_len:]
          if system_file in system_files_to_package_map:
            system_files_to_package_map[system_file] = "--multiple--"
          else:
            system_files_to_package_map[system_file] = module
  return system_files_to_package_map
def package_to_vendor_map(path):
  package_vendor_map = {}
  system_prefix = os.path.join(path, 'system')
  system_prefix_len = len(system_prefix) + 1
  vendor_prefixes = VENDOR_PATH_MAP.keys()
  with open(os.path.join(path, 'module-info.json')) as module_info_json:
    module_info = json.load(module_info_json)
    for module in module_info:
      paths = module_info[module]['path']
      vendor = ""
      if len(paths) == 1:
        path = paths[0]
        for prefix in vendor_prefixes:
          if path.startswith(prefix):
            vendor = VENDOR_PATH_MAP[prefix]
            break
        if vendor == "":
          vendor = "--unknown--"
      else:
        vendor = "--multiple--"
      package_vendor_map[module] = vendor
  return package_vendor_map
def main():
  parser = argparse.ArgumentParser(description=HELP_MSG)
  parser.add_argument("out1", help="First $OUT directory")
  parser.add_argument("out2", help="Second $OUT directory")
  args = parser.parse_args()
  system_files1 = system_files(args.out1)
  system_files2 = system_files(args.out2)
  system_files_diff = set(system_files1) - set(system_files2)
  system_files_map = system_files_to_package_map(args.out1)
  package_vendor_map = package_to_vendor_map(args.out1)
  packages = {}
  for file in system_files_diff:
    if file in system_files_map:
      package = system_files_map[file]
    else:
      package = "--unknown--"
    if package in packages:
      packages[package].append(file)
    else:
      packages[package] = [file]
  with open(os.path.join(args.out1, 'module-info.json')) as module_info_json:
    module_info = json.load(module_info_json)
  writer = csv.writer(sys.stdout, quoting = csv.QUOTE_NONNUMERIC,
                      delimiter = ',', lineterminator = '\n')
  for package, files in packages.iteritems():
    for file in files:
      if package in package_vendor_map:
        vendor = package_vendor_map[package]
      else:
        vendor = "--unknown--"
      full_path = os.path.join(args.out1, 'system', file)
      size = os.stat(full_path).st_size
      if package in module_info.keys():
        module_path = module_info[package]['path']
      else:
        module_path = ''
      writer.writerow([
          file,
          package,
          module_path,
          size,
          vendor])
if __name__ == '__main__':
  main()
