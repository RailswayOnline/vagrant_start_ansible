Руководство по запуску и настройке тестового окружения для деплоя Ruby on Rails приложения. Для запуска и управления виртуальной машиной(ВМ) нам поможет __Vagrant__, ну а установку необходимого ПО на тестовый сервер мы будем делать с помощью __Ansible__. Деплой приложения можно делать с помощью Capistrano.

Конфиг __Ansible__ в дальнейшем можно использовать и для настройки боевого сервера.

При данном подходе деплой Ruby on Rails приложения на production сервер пройдет максимально гладко и быстро.

И так, поехали!

## Задача

- быстро поднять тестовый сервер
- настроить сервер максимально приближенным к боевому для деплоя Rails приложения

## Installation
> Все действия описаны под macOS. С другими OS, я думаю, проблем не должно возникнуть.

**1. Установка VirtualBox:**

На официальном [сайте](https://www.virtualbox.org/wiki/Downloads "VirtualBox") скачиваем *platform packages* последней версии и устанавливаем.

В моём случае можно установить так:
```sh
brew cask install virtualbox
```

На том же сайте скачиваем расширение **Oracle VM VirtualBox Extension Pack**. Расширение одно под все платформы. Далее нужно установить расширение в ранее установленный VirtualBox:
  * запускаем VirtualBox
  * заходим в настройки -> плагины
  * добавляем скачанный плагин

**2. Установка Vagrant**

Так же на официальном [сайте](https://www.vagrantup.com/downloads.html  "Vagrant") скачиваем Vagrant и устанавливаем.

В моём случае можно установить так:

```sh
brew cask install vagrant && brew cask install vagrant-manager
```
Проверяем, что vagrant успешно установлен и ставим нужный нам плагин:
```sh
vagrant -v
vagrant plugin install vagrant-vbguest
```

**3. Установка Ansible**

Идем на официальный [сайт](http://docs.ansible.com/ansible/intro_installation.html#installing-the-control-machine "Ansible") и читаем рекомендуемую установку под вашу OS.

Несмотря на то, что под macOS предпочтительнее воспользоваться пакетным менеджером Python и поставить ansible так `sudo easy_install pip`, `sudo pip install ansible`. Я воспользовался более привычным мне пакетным менеджером brew:
```sh
brew install ansible
```
Далее проверяем, что ansible установлен и устанавливаем библиотеку [rvm_io.ruby](https://github.com/rvm/rvm1-ansible "rvm1-ansible") для установки rvm и ruby через ansible:
```sh
ansible --version
ansible-galaxy install rvm_io.ruby
```

## Vagrant, Ansible
**1. Configuration Vagrant**

После того как все поставили, нам нужно зайти в наш проект и проинициализировать его вагрантом:

> Для установки OS на virtual machine, vagrant использует так называемые [boxes](https://www.vagrantup.com/docs/boxes.html "Docs Vagrant Boxes"). Полный список общедоступных [boxes](https://atlas.hashicorp.com/boxes/search "Atlas Boxes"). Мы установим ubuntu 14.04, название этого boxes **ubuntu/trusty64**.

```sh
cd project_name
vagrant init ubuntu/trusty64
```
Данная команда создаст в корне нашего проекта файл конфиг *Vagrantfile*.

Давайте быстро пробежимся по конфигу.

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"

  # в браузере наше приложение можно будет открыть по ссылке localhost:8080
  config.vm.network "forwarded_port", guest: 80, host: 8080

  # по дефолту vagrant создает виртуальную машину с выделенной для нее
  # оперативной памятью 512 Mb, которой мне не хватило даже для установки всех гемов.
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 2
  end

  # provision сервера можно делать хоть shell скриптами, хоть идти и руками ставить все ПО.
  # мы же напишем таски для ansible.
  config.vm.provision "shell", inline: "echo Hello from Shell"

  config.vm.provision "ansible" do |ansible|
    ansible.verbose = "v"
    ansible.playbook = "ansible/provision.yml"
  end
end
```

**2. Configuration Ansible**
> У Ansible очень подробная и понятная [документация](https://docs.ansible.com/ansible/index.html "Docs Ansible"), если что идем и читаем. В тасках мы описываем нужное нам состояние сервера. И если какой-то конфигурационный файл мы изменим, при следующем прогоне тасков ansible выполнит только то, что мы изменили. Сразу скажу, что shell команды ansible выполнит при каждом прогоне. Поэтому лучше использовать модули ansible, которых хватит на все случаи жизни.

*Перед тем как писать таски составим список того, что мы хотим установить и сделать на сервере:*
  * установить необходимые пакеты
  * поменять время тестового сервера
  * создать пользователя с паролем и нужными правами, скопировать наш public key
  * создать нужные директории и скопировать туда наши конфигурационные файлы для приложения
  * установить nginx и скопировать конфиг для nginx
  * установить db(postgresql)
  * установить redis
  * установить rvm и ruby
  * создать gemset для нашего приложения

В корне нашего Rails приложения создаем папку ansible, в которой будем хранить наши playbook - файлы
в формате *yml*, которые содержат задачи для выполнения на сервере.

Чтобы не быть многословным давайте посмотрим структуру папки ansible:
```
ansible
      |__config
      |     |_cable.yml
      |     |_database.yml
      |     |_puma.rb
      |     |_secrets.yml
      |     |_user_conf
      |
      |__roles
      |     |__create_gemset
      |     |            |__tasks
      |     |                   |_main.yml
      |     |__nginx
      |     |    |__handlers
      |     |    |       |_main.yml
      |     |    |__tasks
      |     |    |      |_main.yml
      |     |    |__templates
      |     |               |_nginx.vagrant.conf
      |     |__postgresql
      |     |           |__tasks
      |     |                  |_main.yml
      |     |__redis
      |     |     |__tasks
      |     |            |_main.yml
      |     |__webserver
      |               |__tasks
      |                     |_create_user.yml
      |                     |_main.yml
      |                     |_packages.yml
      |                     |_pre_deploy.yml
      |                     |_settings.yml
      |
      |__vars
      |     |_main.yml
      |
      |_hosts
      |
      |_provision.yml
```
Файл `provision.yml` - это главный playbook, в нем подключены наши переменные, которые далее
мы посмотрим и собраны все roles для выполнения:
```yml
---
- hosts: 'all'
  become: true

  vars_files:
    - vars/main.yml

  roles:
    - webserver
    - nginx
    - postgresql
    - redis
    - { role: rvm_io.ruby,
        tags: ruby,
        become: yes,

        rvm1_rubies: ['ruby-{{ ruby_version }}'],
        rvm1_install_flags: '--auto-dotfiles --user-install',
        rvm1_install_path: '{{ rvm_path }}',
        rvm1_user: '{{ user }}',
        rvm1_rvm_version: 'stable',
        rvm1_bundler_install: True
      }
    - create_gemset
```

> в фигурных скобках {{  }} при прогоне подставляются переменные, которые мы определим в файле `vars/main.yml`

> конфигурацию для роли [rvm_io.ruby](https://github.com/rvm/rvm1-ansible "rvm_io.ruby") можно посмотреть
в документации на github.


Файл `hosts` - это инвентарный файл, в котором можно группировать отдельно тестовые сервера, сервера
для db, production сервера.
```
[production]
0.0.0.0

# создали группу тестовых серверов и подставили дефолтные значения, которые vagrant создает при
# при запуске сервера
[testserver]
vagrant1 ansible_ssh_host=127.0.0.1 ansible_ssh_port=2222 ansible_ssh_user = vagrant ansible_ssh_private_key_file=../.vagrant/machines/default/virtualbox/private_key
```

В файле `vars/main.yml` собраны все переменные которые подставляются при прогоне тасков.
```yml
---
# Версия ruby
ruby_version: '2.3.3'
# Создаем пользователя, который будет деплоить rails приложение
user: 'deployer'
# Здесь сгенерированный пароль qwerty, инструкция как генерировать ниже
password_user: $6$rounds=656000$ZWVqei8p2LFcDg4k$IGxPqDItlb.wHlq5u25nosec4trU7TcOthTn9ATpno2eLbeai4kVYkeR6xJ4J/jb/kZKkuIL4b0XL6wKmbIoS1
# Название приложения
name_app: 'vagrant_start_ansible'
# path
# Здесь описаны все пути, т.к. деплой мы планируем делать capistrano, то описываем shared директорию,
# в которую мы скопируем наши конфиги для Rails приложения
home_path: '/home/{{ user }}'
rvm_path: '{{ home_path }}/.rvm'
application_path: '{{ home_path }}/{{ name_app }}'
shared_path: '{{ application_path }}/shared'
# for database
# Здесь сгенерированный пароль qwerty, инструкция как генерировать ниже
password_db: md5d8578edf8458ce06fbc5bb76a58c5ca4
# Название базы данных
name_db: '{{ name_app }}_production'
# for nginx config
# При настройке production сервера сюда пропиcываем ip либо domain name
server_name: 'localhost'


# Generate password_user:
# local_machine$ pip install passlib
# local_machine$ python -c "from passlib.hash import sha512_crypt; import getpass; print sha512_crypt.encrypt(getpass.getpass())"
# local_machine$ Password:

# Generate password_db:
# local_machine$ echo "md5`echo -n "very_secret_password" | md5`"
```

Единственное что еще нужно изменить - в файле `roles/webserver/tasks/create_user.yml` указать путь
к вашему публичному ключу на локальной машине:
```yml
---
- name: 'create user and added in sudo group'
  user:
    name: '{{ user }}'
    password: '{{ password_user }}'
    shell: /bin/bash
    groups: sudo
    append: yes

# Меняем путь к id_rsa.pub на свой
- name: 'set authorized keys'
  authorized_key:
    user: '{{ user }}'
    state: present
    key: "{{ lookup('file', '/Users/evgeniy/.ssh/id_rsa.pub') }}"

- name: 'copy user config in /etc/sudoers.d'
  template:
    src: config/user_conf
    dest: '/etc/sudoers.d/{{ user }}'
    owner: root
    group: root
```

В папке `config` лежат конфигурационные файлы для нашего приложения. В файл `secrets.yml` нужно вставить
`secret_key_base:`, в остальные файлы ansible подставит переменные при копировании на сервер.

В папке roles думаю все понятно, в кратце опишу, что каждая роль делает:

`roles/webserver`:
  * устанавливаем нужные pakages на сервер
  * устанавливаем timezone
  * создаем пользователя, копируем public key, копируем конфиг для юзера
  * создаем нужные директории, копируем конфиги для нашего rails приложения

`roles/nginx`:
  * устанавливаем nginx
  * копируем конфиг для nginx из папки `roles/nginx/templates`

`roles/postgresql`:
  * устанавливаем postgresql
  * создаем пользователя для db
  * создаем db

`roles/redis`:
  * устанавливаем redis-server

`roles/create_gemset`:
  * создаем gemset для приложения

С конфигурацией все, пора запускать тестовый сервер.

## Start
Создаем сервер в виртульной машине следующей командой:
```sh
vagrant up
```
> Можно заварить кофе и смотреть как наш сервер разворачивается. При первом запуске vagrant скачивает,
указанный нами boxes для VirtualBox, поэтому придется немного подождать.
Далее установка должна занять 7-10 минут.

:tada: Поздравляю! :tada: Сервер установлен и готов к деплою!

Зайти на тестовый сервер можно командой `vagrant ssh`, но мы зайдем на сервер под пользователем,
которого недавно создали:

```sh
ssh -p 2222 deployer@127.0.0.1
```
> При желании можно проверить, что все установлено, зайти в базу данных под пользователем `deployer`
и указанным паролем, проверить скопированные файлы конфигурации.

## Что дальше?
Далее делаем деплой на тестовый сервер рекомендуемым инструментом(Capistrano) для разворачивания Rails приложений.

Я устанавливаю capistrano в приложение следующей командой:
```sh
bundle exec cap install STAGES=vagrant,production
```
В файле `vagrant.rb` указываем `server '127.0.0.1'`, нашего пользователя, от лица которого будет
происходить деплой, и не забываем указать shh порт 2222. Все остальные настройки
как для production сервера.

Деплой:
```sh
cap vagrant deploy
```
**Открываем приложение в любом браузере по ссылке [localhost:8080](http://localhost:8080 "Localhost").**

Чтобы остановить виртуальную машину, в папке с проектом вводим следующую команду:
```sh
vagrant halt
```

Запускаем тестовый сервер:
```sh
vagrant up
```

Когда изменили какой-либо файл конфигурации в папке ansible, нужно прогнать наш playbook командой:
```sh
vagrant provision
```


Надеюсь данное руководство кому-нибудь поможет быстро разобраться с данной темой!
