[web]
%{ for ip in web ~}
web1 ansible-host=${ip} ansible-user=ubuntu
web2 ansible-host=${ip} ansible-user=ubuntu
%{ endfor ~}

[db]
%{ for ip in db ~}
db ansible-host=${ip} ansible-user=ubuntu
%{ endfor ~}
