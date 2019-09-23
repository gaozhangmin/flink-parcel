# flink-parcel
1. 下载制作包
```
git clone https://github.com/TigerTORA/flink-parcel.git
```
2. 生成parcel文件
```
./build.sh  parcel
```
3. 生成csd文件
```
#on yarn 版本
./build.sh  csd_on_yarn

#standalone版本
./build.sh  csd_standalone
```
说明：在如果集群开启了安全，需要配置security.kerberos.login.keytab和security.kerberos.login.principal两个参数才能正正常启动。
