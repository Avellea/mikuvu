import shutil

def main():
    build_num = input("Enter build number: ")

    shutil.make_archive("MikuVU", "zip", "src")
    shutil.move("MikuVU.zip", f"MikuVU_{build_num}.vpk")
    


if __name__ == "__main__":
    main()