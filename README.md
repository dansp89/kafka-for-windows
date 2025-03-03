# Apache Kafka Installation Script for Windows

This project provides a PowerShell script to automate the installation of **Apache Kafka** on **Windows** systems. It also includes optional Java installation (OpenJDK) and configures Kafka to run in **KRaft mode** (without Zookeeper).

---

## Features

- **Automatic Kafka Installation**: Downloads and installs the latest (or specified) version of Apache Kafka.
- **KRaft Mode Configuration**: Configures Kafka to run without Zookeeper.
- **Java Installation**: Installs OpenJDK if Java is not already installed.
- **Disk Space Check**: Verifies if there is enough disk space before proceeding with the installation.
- **Interactive Menus**: Provides an interactive menu to select Kafka and Java versions.
- **Demo Example**: Includes a basic Kafka demo to test the installation.

---

## Prerequisites

- **Windows 10 or later** (tested on Windows 10/11).
- **PowerShell 5.1 or later** (included by default in Windows).
- **Internet connection** (to download Kafka and Java).

---

## How to Use

1. **Download the Script**:
   - Clone this repository or download the `install.ps1` script.

2. **Run the Script**:
   - Open PowerShell as **Administrator**.
   - Navigate to the directory where the script is located.
   - Run the script:
     ```powershell
     .\install.ps1
     ```

3. **Follow the Instructions**:
   - The script will guide you through the installation process, including:
     - Checking disk space.
     - Installing Java (if needed).
     - Selecting and installing Kafka.
     - Configuring Kafka in KRaft mode.
   - At the end, you can choose to run a basic Kafka demo.

> Or use in powershell terminal:
```sh
irm https://cdn.jsdelivr.net/gh/dansp89/kafka-for-windows@main/install.ps1 | iex
```
---

## Project Structure

- **`install.ps1`**: The main PowerShell script for installing Kafka and Java.
- **`.gitignore`**: Specifies files and directories to ignore in version control.
- **`README.md`**: This file, providing an overview of the project.

---

## Customization

- **Kafka Version**: By default, the script installs the latest Kafka version. You can specify a version by modifying the script or selecting it from the interactive menu.
- **Java Version**: The script installs OpenJDK by default. You can choose a specific version during the installation.
- **Installation Directory**: Kafka and Java are installed in `C:\kafka` and `C:\Java`, respectively. You can modify these paths in the script if needed.

---

## Demo Example

After installation, the script offers to run a basic Kafka demo:
1. Creates a Kafka topic named `test-topic`.
2. Starts a producer to send messages to the topic.
3. Starts a consumer to read messages from the topic.

This demo helps verify that Kafka is installed and running correctly.

---

## Troubleshooting

- **Insufficient Disk Space**: Ensure you have at least **1 GB** of free space on the `C:` drive.
- **Java Installation Issues**: If Java fails to install, check your internet connection or manually install OpenJDK.
- **Kafka Startup Issues**: Ensure no other applications are using ports `9092` or `9093`. You can modify the ports in the `server.properties` file.

---

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvement, please:
1. Open an **Issue**.
2. Submit a **Pull Request**.

---

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **Apache Kafka**: [https://kafka.apache.org/](https://kafka.apache.org/)
- **OpenJDK**: [https://openjdk.org/](https://openjdk.org/)
- **PowerShell Documentation**: [https://learn.microsoft.com/en-us/powershell/](https://learn.microsoft.com/en-us/powershell/)

---

## Author

- **DanSP** - Developer and maintainer of this project.
- **Author URL:** [https://github.com/dansp89](https://github.com/dansp89)
- **Project URL:** [https://github.com/dansp89/kafka-for-windows](https://github.com/dansp89/kafka-for-windows)