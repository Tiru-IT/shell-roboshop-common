#!/bin/bash

USER_ID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$( echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log" #/var/log/shell-roboshop/mongodb.log
MONGODB_HOST="mongodb.tirusatrapu.fun"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
SATRT_TIME=$(date +%s)
echo -e "Script stated executed at: $(date)" | tee -a $LOG_FILE

check_root(){
    if [ $USER_ID -ne 0 ]; then
        echo -e "ERROR::Please run this script with root privelege"
        exit 1
    fi 
}

VALIDATE(){
    if [ $? -ne 0 ]; then 
        echo -e "$2 ...$R FAILER $N" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "$2 ...$G SUCCESS $N" |tee -a $LOG_FILE
    fi
}

app_setup(){
    id roboshope &>>$LOG_FILE 
    if [ $? -ne 0 ]; then
        useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    else
        echo -e "User already exit $Y SKIPPING $N"
    fi

    mkdir -p /app 
    VALIDATE $? "create directory"

    curl -o /tmp/$app_name.zip https://roboshop-artifacts.s3.amazonaws.com/$app_name-v3.zip &>>$LOG_FILE
    VALIDATE $? "Downloading $app_name appilication"

    cd /app 
    VALIDATE $? "move to app directory"

    rm -rf /app/*
    VALIDATE $? "removing existing code"

    unzip /tmp/$app_name.zip &>>$LOG_FILE
    VALIDATE $? "unzip the code"
}

nodejs_setup(){
    dnf module disable nodejs -y &>>$LOG_FILE
    VALIDATE $? "disable nodejs"

    dnf module enable nodejs:20 -y &>>$LOG_FILE
    VALIDATE $? "enable nodejs:20"

    dnf install nodejs -y &>>$LOG_FILE
    VALIDATE $? "install nodejs"

    npm install &>>$LOG_FILE
    VALIDATE $? "npm install"
}

java_setup(){
    dnf install maven -y &>>$LOG_FILE
    VALIDATE $? "install maven"

    mvn clean package &>>$LOG_FILE
    VALIDATE $? "package the appilication"

    mv target/shipping-1.0.jar shipping.jar &>>$LOG_FILE
    VALIDATE $? "Renaming the artifact"
}

pytho_setup(){
    dnf install python3 gcc python3-devel -y &>>$LOG_FILE
    VALIDATE $? "install pytho3"

    pip3 install -r requirements.txt &>>$LOG_FILE
    VALIDATE $? "Installing dependencies"

}

mongodb_setup(){
    cp mongo.repo /etc/yum.repos.d/mongo.repo
    VALIDATE $? "Adding mongo repo"

    dnf install mongodb-org -y &>>$LOG_FILE
    VALIDATE $? "Installing MongoDB"

    systemctl enable mongod &>>$LOG_FILE
    VALIDATE $? "Enable MongoDB"

    systemctl start mongod 
    VALIDATE $? "Start MongoDB"

    sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
    VALIDATE $? "Allowing remote connections to MongoDB"

}
mysql_ssetup(){
    dnf install mysql-server -y &>>$LOG_FILE
    VALIDATE $? "install mysql"

    systemctl enable mysqld &>>$LOG_FILE
    VALIDATE $? "enable mysql"

    systemctl start mysqld
    VALIDATE $? "sart mysqld"

    mysql_secure_installation --set-root-pass RoboShop@1 &>>$LOG_FILE
    VALIDATE $? "set password"
}

redis_setup(){
    dnf module disable redis -y &>>$LOG_FILE
    dnf module enable redis:7 -y &>>$LOG_FILE
    dnf install redis -y &>>$LOG_FILE
    echo -e "redis install $G SUCCESS $N"

    sed -i -e 's/127.0.0.1/0.0.0.0/g' -e '/protected-mode/ c protected-mode no' /etc/redis/redis.conf &>>$LOG_FILE
    systemctl enable redis &>>$LOG_FILE &>>LOG_FILE
    systemctl start redis 
    echo -e "redis start $G SUCCESS $N"
}

raabbitmq_setup(){
    cp $SCRIPT_DIR/rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo &>>$LOG_FILE
    VALIDATE $? "copy the systemctl service"

    dnf install rabbitmq-server -y &>>$LOG_FILE

    systemctl enable rabbitmq-server &>>$LOG_FILE
    systemctl start rabbitmq-server &>>$LOG_FILE
    VALIDATE $? "install rabbitmq server"
    echo -e "install $G SUCCESS $N"

    id roboshop &>>$LOG_FILE
    if [ $? -ne 0 ]; then
        rabbitmqctl add_user roboshop roboshop123 &>>$LOG_FILE
    else
        echo -e "user already exit $Y SKIPPING $N"
    fi 

    rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>>$LOG_FILE
    echo -e "rabbit mq $G success $N"
}


nginx_setup(){
    dnf module disable nginx -y &>>$LOG_FILE
    dnf module enable nginx:1.24 -y &>>$LOG_FILE
    dnf install nginx -y &>>$LOG_FILE
    VALIDATE $? "install nginx"

    systemctl enable nginx &>>$LOG_FILE
    systemctl start nginx 
    VALIDATE $? "start nginx"

    rm -rf /usr/share/nginx/html/* &>>$LOG_FILE
    curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>$LOG_FILE
    VALIDATE $? "download frontend code"
    
    cd /usr/share/nginx/html 
    unzip /tmp/frontend.zip &>>$LOG_FILE
    VALIDATE $? "unzip the code"

    cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf &>>$LOG_FILE
}

systemd_setup(){
    cp $SCRIPT_DIR/$app_name.service /etc/systemd/system/$app_name.service
    VALIDATE $? "copy systemctl service"

    systemctl daemon-reload
    systemctl enable $app_name &>>$LOG_FILE
    VALIDATE $? "Enable $app_name"
}

mongosh_setup(){
    cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo

    dnf install mongodb-mongosh -y &>>$LOG_FILE
    VALIDATE $? "install mongodb-mongosh"


    INDEX=$(mongosh mongodb.tirusatrapu.fun --quiet --eval "db.getMongo().getDBNames().indexOf('catalogue')")
    if [ $INDEX -le 0 ]; then
        mongosh --host $MONGODB_HOST </app/db/master-data.js &>>$LOG_FILE
        VALIDATE $? "Load catalogue products"
    else
        echo -e "Catalogue products already loaded ... $Y SKIPPING $N"
    fi

}

app_restart(){
    systemctl restart $app_name
    VALIDATE $? "Restarted $app_namee"
}

total_time(){
    END_TIME=$(date +%s)
    TOTAL_TIME=$(( $END_TIME - $SATRT_TIME ))
    echo -e "Script exicuted in $TOTAL_TIME $Y seconds $N"
}