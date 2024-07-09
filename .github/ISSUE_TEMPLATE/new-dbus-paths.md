---
name: New dbus path
about: 'When (a) new dbus path(s) is added to Venus '
title: 'New dbus path: <path>'
labels: ''
assignees: izak

---

(replace with a short description, explaining how it works)

Dbus service: com.victronenergy.example

 Path                   | Unit/Enum              | Storage (long term/last value only
------------------------|------------------------|-----------------------------------
 /Dc/0/Voltage          | DC V                   | long term
 /Alarms/SomethingWrong | 0=OK;1=Warning;2=Alarm | long term

TODO
- [ ] Add new attributes to VRM logger (ibu)
- [ ] Log issue for new attributes in [VRM tracker][1] (ibu)
- [ ] Add relevant paths to dbus-modbustcp (ibu)
- [ ] Add alarms to venus-platform (Rein)
- [ ] Add product ID if new product (ibu)
- [ ] Update the [dbus wiki][2] (ibu)

[1]: https://github.com/victronenergy/vrm-portal/issues/new/choose
[2]: https://github.com/victronenergy/venus/wiki/dbus
