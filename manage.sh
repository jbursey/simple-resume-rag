#!/usr/bin/env bash

set -e
#set -x

# vars
ACTION="$1"

case "$ACTION" in

    up)
        echo "===================="
        echo "==== Building Images"
        echo "===================="
        podman image build -t local-ollama -f ./ollama/Dockerfile ./ollama
        podman image build -t local-mysql -f ./mysql/Dockerfile ./mysql
        podman image build -t local-qdrant -f ./qdrant/Dockerfile ./qdrant
        podman image build -t local-web -f ./web/Dockerfile ./web

        echo ""

        echo "====================="
        echo "==== Creating Network"
        echo "====================="
        podman network create local-llm-network

        echo ""

        echo "========================"
        echo "==== Starting Containers"
        echo "========================"
        podman container run --name local-container-ollama --network local-llm-network -d -v ollama_data:/root/.ollama -p "11434:11434" local-ollama
        podman container run --name local-container-mysql --network local-llm-network -d -p "3306:3306" local-mysql
        podman container run --name local-container-qdrant --network local-llm-network -d -p "6333:6333" -p "6334:6334" local-qdrant
        podman container run --name local-container-web --network local-llm-network -d -v ./web/:/app -p "8000:8000" local-web

        echo ""

        echo "=================================="
        echo "==== Waiting for MySQL Readiness"
        echo "=================================="
        checks=0
        until [ "$checks" -ge 2 ]; do
        if podman container exec local-container-mysql mysql -u root -ppasswordllm -e "SELECT 1;" >/dev/null 2>&1; then
            checks=$((checks + 1))
        else
            checks=0
            sleep 2
            echo -n "."
        fi
        [ "$checks" -lt 2 ] && sleep 1
        done
        echo " MySQL is up!"

        echo "===> Importing Database Schema..."
        podman container exec -i local-container-mysql mysql -u root -ppasswordllm llm_memory < "./mysql/schema.sql"

        echo ""

        echo "================================="
        echo "==== Waiting for Ollama Readiness"
        echo "================================="
        until podman container exec local-container-ollama curl -s http://localhost:11434/api/tags &>/dev/null; do
            sleep 2
            echo -n "."
        done
        echo " Ollama is up!"

        echo ""

        

        echo ""

        echo "==================="
        echo "==== Pulling Models"
        echo "==================="
        podman container exec local-container-ollama ollama pull llama3.2
        podman container exec local-container-ollama ollama list 

        echo ""

        echo "========="
        echo "==== Urls"
        echo "========="

        echo "web ui:    http://127.0.0.1:8000/"
        echo "qdrant ui: http://127.0.0.1:6333/dashboard"
        echo "ollama:    http://127.0.0.1:11434"

        echo ""

        ;;
    down)
        echo "=================="
        echo "==== Shutting Down"
        echo "=================="
        podman container rm -f local-container-ollama local-container-mysql local-container-qdrant local-container-web
        podman network rm -f local-llm-network
        ;;
esac