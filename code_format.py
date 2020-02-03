import glob
import subprocess

glob_paths = ['YMHTTP/Classes/core/*.[h, m]', 'YMHTTP/Classes/*.[h, m]']
format_files = []

for glob_path in glob_paths:
    files = glob.glob(glob_path, recursive=True)
    format_files.extend(files)

for format_file in format_files:
    subprocess.call('clang-format -style=file -i ' + format_file, shell=True)


print('code format complete!!')