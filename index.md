---
layout: default
title: Home
---

# Welcome!

Hello and welcome to _Computational Guides for Ecologists_!

The idea of this website is to provide a platform of open-source documents
that provide useful tutorials on all things computational for ecologists.

Anyone can download the documents edit them or add their own. Changes are then
uploaded to this website for others to see, use and make their own changes --
computational guides by ecologists for ecologists!

At the moment this is just the test website, hence 'test' in the URL and the
hit-and-miss design. But if you want to contribute a tutorial document on
anything computational you can! Read this guide to get started
[how to contribute]({{ site.baseurl }}/docs/how_to_contribute).

## Current list of tutorials in development

{% for doc in site.docs %}
* [{{ doc.title }}]({{ site.baseurl }}{{ doc.url }})
    * _Status_: {{ doc.status }}
    * _Author(s)_: {{ doc.author | join: ', ' }}{% endfor %}
