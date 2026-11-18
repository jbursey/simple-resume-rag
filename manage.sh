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
        wslc image build -t local-ollama -f ./ollama/Dockerfile ./ollama
        wslc image build -t local-mysql -f ./mysql/Dockerfile ./mysql
        wslc image build -t local-qdrant -f ./qdrant/Dockerfile ./qdrant
        wslc image build -t local-web -f ./web/Dockerfile ./web

        echo ""

        echo "====================="
        echo "==== Creating Network"
        echo "====================="
        wslc network create local-llm-network

        echo ""

        echo "========================"
        echo "==== Starting Containers"
        echo "========================"
        wslc container run --name local-container-ollama -v ollama_data:/root/.ollama -d -p "11434:11434" local-ollama
        wslc container run --name local-container-mysql -d -p "3306:3306" local-mysql
        wslc container run --name local-container-qdrant -d local-qdrant
        wslc container run --name local-container-web -d -p "8000:8000" local-web

        echo ""

        echo "=================================="
        echo "==== Waiting for MySQL Readiness"
        echo "=================================="
        until wslc container exec local-container-mysql mysql -u root -ppasswordllm -e "SELECT 1;" &>/dev/null; do
            sleep 2
            echo -n "."
        done
        echo " MySQL is up!"

        echo "===> Importing Database Schema..."
        wslc container exec -i local-container-mysql mysql -u root -ppasswordllm llm_memory < "./mysql/schema.sql"

        echo ""

        echo "================================="
        echo "==== Waiting for Ollama Readiness"
        echo "================================="
        until wslc container exec local-container-ollama curl -s http://localhost:11434/api/tags &>/dev/null; do
            sleep 2
            echo -n "."
        done
        echo " Ollama is up!"

        echo ""

        

        echo ""

        echo "==================="
        echo "==== Pulling Models"
        echo "==================="
        wslc container exec local-container-ollama ollama pull llama3.2
        wslc container exec local-container-ollama ollama list 

        echo ""

        ;;
    down)
        echo "=================="
        echo "==== Shutting Down"
        echo "=================="
        wslc container rm -f local-container-ollama local-container-mysql local-container-qdrant local-container-web
        wslc network rm -f local-llm-network
        ;;
esac