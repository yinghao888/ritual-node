#!/bin/bash

# 重启 Docker 容器
  echo "确保在重启前所有容器已停止..."
  cd ~/infernet-container-starter
  docker compose -f deploy/docker-compose.yaml down
  
  # 如果容器存在，手动移除
  echo "移除任何残留容器..."
  docker rm -f infernet-fluentbit infernet-redis infernet-anvil infernet-node 2>/dev/null || true

# 函数：显示标志
display_logo() {
  sleep 2
  curl -s https://raw.githubusercontent.com/ToanBm/user-info/main/logo.sh | bash
  sleep 1
}

# 函数：显示菜单
display_menu() {
  clear
  display_logo
  echo "===================================================="
  echo "     RITUAL NETWORK INFERNET 自动安装程序          "
  echo "     推特撸毛小学生  @hao3313076                    "
  echo "===================================================="
  echo ""
  echo "请选择一个选项："
  echo "1) 安装 Ritual Network Infernet"
  echo "2) 卸载 Ritual Network Infernet"
  echo "3) 退出"
  echo ""
  echo "===================================================="
  read -p "输入您的选择 (1-3)： " choice
}

# 函数：安装 Ritual Network Infernet
install_ritual() {
  clear
  display_logo
  echo "===================================================="
  echo "     ?? 正在安装 RITUAL NETWORK INFERNET ??        "
  echo "===================================================="
  echo ""
  
  # 请求输入私钥，隐藏输入内容
  echo "请输入您的私钥（如果需要，请带上 0x 前缀）"
  echo "注意：为安全起见，输入内容将隐藏"
  read -s private_key
  echo "已接收私钥（为安全起见已隐藏）"
  
  # 如果缺少 0x 前缀，自动添加
  if [[ ! $private_key =~ ^0x ]]; then
    private_key="0x$private_key"
    echo "已为私钥添加 0x 前缀"
  fi
  
  echo "正在安装依赖项..."
  
  # 更新软件包和构建工具
  sudo apt update && sudo apt upgrade -y
  sudo apt -qy install curl git jq lz4 build-essential screen
  
  # 安装 Docker
  echo "正在安装 Docker..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  sudo docker run hello-world
  
  # 安装 Docker Compose
  echo "正在安装 Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
  chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
  docker compose version
  sudo usermod -aG docker $USER
  docker run hello-world
  
  # 克隆仓库
  echo "正在克隆仓库..."
  git clone https://github.com/ritual-net/infernet-container-starter
  cd infernet-container-starter
  
  # 创建配置文件
  echo "正在创建配置文件..."
  
  # 创建带有私钥的 config.json
  cat > ~/infernet-container-starter/deploy/config.json << EOL
{
    "log_path": "infernet_node.log",
    "server": {
        "port": 4000,
        "rate_limit": {
            "num_requests": 100,
            "period": 100
        }
    },
    "chain": {
        "enabled": true,
        "trail_head_blocks": 3,
        "rpc_url": "https://mainnet.base.org/",
        "registry_address": "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170",
        "wallet": {
          "max_gas_limit": 4000000,
          "private_key": "${private_key}",
          "allowed_sim_errors": []
        },
        "snapshot_sync": {
          "sleep": 3,
          "batch_size": 10000,
          "starting_sub_id": 180000,
          "sync_period": 30
        }
    },
    "startup_wait": 1.0,
    "redis": {
        "host": "redis",
        "port": 6379
    },
    "forward_stats": true,
    "containers": [
        {
            "id": "hello-world",
            "image": "ritualnetwork/hello-world-infernet:latest",
            "external": true,
            "port": "3000",
            "allowed_delegate_addresses": [],
            "allowed_addresses": [],
            "allowed_ips": [],
            "command": "--bind=0.0.0.0:3000 --workers=2",
            "env": {},
            "volumes": [],
            "accepted_payments": {},
            "generates_proofs": false
        }
    ]
}
EOL

  # 将配置复制到容器文件夹
  cp ~/infernet-container-starter/deploy/config.json ~/infernet-container-starter/projects/hello-world/container/config.json
  
  # 创建 Deploy.s.sol
  cat > ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol << EOL
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {SaysGM} from "../src/SaysGM.sol";

contract Deploy is Script {
    function run() public {
        // 设置钱包
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 记录地址
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("已加载部署者: ", deployerAddress);

        address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;
        // 创建消费者
        SaysGM saysGm = new SaysGM(registry);
        console2.log("已部署 SaysHello: ", address(saysGm));

        // 执行
        vm.stopBroadcast();
        vm.broadcast();
    }
}
EOL

  # 创建 Makefile
  cat > ~/infernet-container-starter/projects/hello-world/contracts/Makefile << EOL
# 伪目标是不实际创建文件的目标
.phony: deploy

# anvil 的第三个默认地址
sender := ${private_key}
RPC_URL := https://mainnet.base.org/

# 部署合约
deploy:
    @PRIVATE_KEY=\$(sender) forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url \$(RPC_URL)

# 调用 sayGM()
call-contract:
    @PRIVATE_KEY=\$(sender) forge script script/CallContract.s.sol:CallContract --broadcast --rpc-url \$(RPC_URL)
EOL

  # 编辑 docker-compose.yaml 中的节点版本
  sed -i 's/infernet-node:.*/infernet-node:1.4.0/g' ~/infernet-container-starter/deploy/docker-compose.yaml
  
  # 使用 systemd 部署容器而非 screen
  echo "正在为 Ritual Network 创建 systemd 服务..."
  cd ~/infernet-container-starter
  
  # 创建由 systemd 运行的脚本
  cat > ~/ritual-service.sh << EOL
#!/bin/bash
cd ~/infernet-container-starter
echo "在 \$(date) 开始容器部署" > ~/ritual-deployment.log
project=hello-world make deploy-container >> ~/ritual-deployment.log 2>&1
echo "容器部署在 \$(date) 完成" >> ~/ritual-deployment.log

# 保持容器运行
cd ~/infernet-container-starter
while true; do
  echo "在 \$(date) 检查容器" >> ~/ritual-deployment.log
  if ! docker ps | grep -q "infernet"; then
    echo "容器已停止。在 \$(date) 重启" >> ~/ritual-deployment.log
    docker compose -f deploy/docker-compose.yaml up -d >> ~/ritual-deployment.log 2>&1
  else
    echo "容器在 \$(date) 正常运行" >> ~/ritual-deployment.log
  fi
  sleep 300
done
EOL
  
  chmod +x ~/ritual-service.sh
  
  # 创建 systemd 服务文件
  sudo tee /etc/systemd/system/ritual-network.service > /dev/null << EOL
[Unit]
Description=Ritual Network Infernet 服务
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=/bin/bash /root/ritual-service.sh
Restart=always
RestartSec=30
StandardOutput=append:/root/ritual-service.log
StandardError=append:/root/ritual-service.log

[Install]
WantedBy=multi-user.target
EOL

  # 重新加载 systemd，启用并启动服务
  sudo systemctl daemon-reload
  sudo systemctl enable ritual-network.service
  sudo systemctl start ritual-network.service
  
  # 验证服务是否运行
  sleep 5
  if sudo systemctl is-active --quiet ritual-network.service; then
    echo "? Ritual Network 服务启动成功！"
  else
    echo "?? 警告：服务可能未正确启动。正在检查状态..."
    sudo systemctl status ritual-network.service
  fi
  
  echo "服务日志正在保存到 ~/ritual-deployment.log"
  echo "您可以使用以下命令检查服务状态：sudo systemctl status ritual-network.service"
  echo "继续安装..."
  echo ""
  
  # 等待部署初始化
  echo "等待部署初始化..."
  sleep 10
  
  # 再次检查服务状态
  echo "验证服务状态..."
  if sudo systemctl is-active --quiet ritual-network.service; then
    echo "? Ritual Network 服务正常运行。"
  else
    echo "?? 服务未正确运行。尝试重启..."
    sudo systemctl restart ritual-network.service
    sleep 5
    sudo systemctl status ritual-network.service
  fi
  
  # 启动容器
  echo "正在启动容器..."
  docker compose -f deploy/docker-compose.yaml up -d
  sleep 2

  # 停止容器（因 anvil 错误添加停止操作）
  docker compose -f deploy/docker-compose.yaml down
  
  # 安装 Foundry
  echo "正在安装 Foundry..."
  cd
  mkdir -p foundry
  cd foundry
  
  # 终止任何运行中的 anvil 进程
  pkill anvil 2>/dev/null || true
  sleep 2
  
  # 安装 Foundry
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc
  
  echo "执行 foundryup..."
  export PATH="$HOME/.foundry/bin:$PATH"
  $HOME/.foundry/bin/foundryup || foundryup
  
  # 检查 forge 是否在标准路径中，否则更新 PATH
  if ! command -v forge &> /dev/null; then
    echo "将 Foundry 添加到 PATH..."
    export PATH="$HOME/.foundry/bin:$PATH"
    echo 'export PATH="$PATH:$HOME/.foundry/bin"' >> ~/.bashrc
    
    # 检查是否存在旧的 forge 二进制文件
    if [ -f /usr/bin/forge ]; then
      echo "移除旧的 forge 二进制文件..."
      sudo rm /usr/bin/forge
    fi
  fi

  # 启动容器
  echo "正在启动容器..."
  docker compose -f deploy/docker-compose.yaml up -d
  sleep 2
  
  # 安装必要的库并进行错误处理
  echo "正在安装所需库..."
  cd ~/infernet-container-starter/projects/hello-world/contracts
  
  # 如果存在现有库，则移除
  rm -rf lib/forge-std 2>/dev/null || true
  rm -rf lib/infernet-sdk 2>/dev/null || true
  
  # 尝试安装 forge-std
  echo "正在安装 forge-std..."
  forge install --no-commit foundry-rs/forge-std || $HOME/.foundry/bin/forge install --no-commit foundry-rs/forge-std
  
  # 验证 forge-std 是否安装成功
  if [ ! -d "lib/forge-std" ]; then
    echo "重试安装 forge-std..."
    rm -rf lib/forge-std 2>/dev/null || true
    $HOME/.foundry/bin/forge install --no-commit foundry-rs/forge-std
  fi
  
  # 尝试安装 infernet-sdk
  echo "正在安装 infernet-sdk..."
  forge install --no-commit ritual-net/infernet-sdk || $HOME/.foundry/bin/forge install --no-commit ritual-net/infernet-sdk
  
  # 验证 infernet-sdk 是否安装成功
  if [ ! -d "lib/infernet-sdk" ]; then
    echo "重试安装 infernet-sdk..."
    rm -rf lib/infernet-sdk 2>/dev/null || true
    $HOME/.foundry/bin/forge install --no-commit ritual-net/infernet-sdk
  fi
  
  # 返回根目录
  cd ~/infernet-container-starter
  
  # 再次重启 Docker 容器
  echo "再次重启 Docker 容器..."
  docker compose -f deploy/docker-compose.yaml down
  docker rm -f infernet-fluentbit infernet-redis infernet-anvil infernet-node 2>/dev/null || true
  docker compose -f deploy/docker-compose.yaml up -d
  
  # 部署消费者合约
  echo "正在部署消费者合约..."
  export PRIVATE_KEY="${private_key#0x}"  # 如果存在 0x 前缀，则移除以适配 Foundry
  cd ~/infernet-container-starter
  
  # 运行部署并捕获输出以提取合约地址
  echo "运行合约部署并捕获地址..."
  deployment_output=$(project=hello-world make deploy-contracts 2>&1)
  echo "$deployment_output" > ~/deployment-output.log
  
  # 使用 grep 和正则表达式提取合约地址
  contract_address=$(echo "$deployment_output" | grep -oE "Contract Address: 0x[a-fA-F0-9]+" | awk '{print $3}')
  
  if [ -z "$contract_address" ]; then
    echo "?? 无法自动提取合约地址。"
    echo "请检查 ~/deployment-output.log 并手动输入合约地址："
    read -p "在 Basescan 上粘贴您的地址，复制智能合约并在此粘贴（格式为 0x...）： " contract_address
  else
    echo "? 成功提取合约地址：$contract_address"
  fi
  
  # 保存合约地址以供将来使用
  echo "$contract_address" > ~/contract-address.txt
  
  # 使用新合约地址更新 CallContract.s.sol
  echo "使用合约地址更新 CallContract.s.sol：$contract_address"
  cat > ~/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol << EOL
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {SaysGM} from "../src/SaysGM.sol";

contract CallContract is Script {
    function run() public {
        // 设置钱包
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 调用合约
        SaysGM saysGm = SaysGM($contract_address);
        saysGm.sayGM();

        // 执行
        vm.stopBroadcast();
        vm.broadcast();
    }
}
EOL

  # 调用合约
  echo "调用合约以测试功能..."
  cd ~/infernet-container-starter
  project=hello-world make call-contract
  
  echo "检查容器是否正在运行..."
  docker ps | grep infernet
  
  echo "检查节点日志..."
  docker logs infernet-node 2>&1 | tail -n 20
  
  echo ""
  echo "按任意键返回菜单..."
  read -n 1
}

# 函数：卸载 Ritual Network Infernet
uninstall_ritual() {
  clear
  display_logo
  echo "===================================================="
  echo "     ?? 正在卸载 RITUAL NETWORK INFERNET ??        "
  echo "===================================================="
  echo ""
  
  read -p "您确定要卸载吗？(y/n)： " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "卸载已取消。"
    echo "按任意键返回菜单..."
    read -n 1
    return
  fi
  
  echo "停止并移除 systemd 服务..."
  # 停止并禁用 systemd 服务
  sudo systemctl stop ritual-network.service
  sudo systemctl disable ritual-network.service
  sudo rm /etc/systemd/system/ritual-network.service
  sudo systemctl daemon-reload
  
  echo "停止并移除 Docker 容器..."
  # 停止并移除 Docker 容器
  docker compose -f ~/infernet-container-starter/deploy/docker-compose.yaml down 2>/dev/null
  
  # 如果容器仍存在，手动移除
  echo "移除存在的容器..."
  docker rm -f infernet-fluentbit infernet-redis infernet-anvil infernet-node 2>/dev/null || true
  
  echo "移除安装文件..."
  # 移除安装目录和脚本
  rm -rf ~/infernet-container-starter
  rm -rf ~/foundry
  rm -f ~/ritual-service.sh
  rm -f ~/ritual-deployment.log
  rm -f ~/ritual-service.log
  
  echo "清理 Docker 资源..."
  # 移除未使用的 Docker 资源
  docker system prune -f
  
  echo ""
  echo "===================================================="
  echo "? RITUAL NETWORK INFERNET 卸载完成 ?"
  echo "===================================================="
  echo ""
  echo "如果您想完全移除 Docker，请运行以下命令："
  echo "sudo apt-get purge docker-ce docker-ce-cli containerd.io"
  echo "sudo rm -rf /var/lib/docker"
  echo "sudo rm -rf /etc/docker"
  echo ""
  echo "按任意键返回菜单..."
  read -n 1
}

# 主程序
main() {
  while true; do
    display_menu
    
    case $choice in
      1)
        install_ritual
        ;;
      2)
        uninstall_ritual
        ;;
      3)
        clear
        display_logo
        echo "感谢使用 Ritual Network Infernet 自动安装程序！"
        echo "正在退出..."
        exit 0
        ;;
      *)
        echo "无效选项。按任意键重试..."
        read -n 1
        ;;
    esac
  done
}

# 运行主程序
main
