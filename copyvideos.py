import os
from tkinter import filedialog, Tk
from shutil import copy2

# Ask for a root directory
tk = Tk()
tk.withdraw()

all_files = []

while True:
	selected_dir = filedialog.askdirectory(initialdir = 'C:\\SERVER')

	for root, dirs, files in os.walk(selected_dir):
		for file in files:
			if file.endswith("_cropped.mp4"):
				all_files.append(os.path.join(root, file))
				print(os.path.join(root, file))
	
	ans = input("Continue adding directories [Y/N]?\n")
	if ans.upper() == 'Y':
		continue
	else:
		break

if len(all_files) > 0:
	ans = input("Copy " + str(len(all_files)) + " found files [Y/N]?\n")
	if ans.upper() == 'Y':
		selected_dir = filedialog.askdirectory(initialdir = 'D:\\DeepLabCut\\videos')
		for file in all_files:
			print("Copying file " + file + " to new location " + selected_dir)
			copy2(file, selected_dir)
		print("Finished copying " + str(len(all_files)) + " files!")