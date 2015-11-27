#! /bin/usr/env python
# D.J. Bennett
# 19/04/2015
"""
Build docs for the FGE website from the /BES-QSIG/docs repository.

Usage:
python build.py
jekyll build

Then, upload _site/ to gh-pages branch.
"""

# LIBS
import os
import re
import sys
import subprocess
import operator
from github import Github
from shutil import copyfile
from cgi import escape


# GLOBALS
front_matter = """---
layout: doc
authors: {0}
lastchange: {1}
title: {2}
status: {3}
permalink: {4}
source: {5}
source_author: {6}
---
"""
part_github_yml = """- name: {0}
  email: {1}
  affiliation: {2}
  image: {3}
  github_username: {4}
"""


# FUNCTIONS
def htmlFriendly(text):
    """Return HTML friendly text"""
    return escape(unicode(text)).encode('ascii', 'xmlcharrefreplace')


def gen_github_yaml():
    """Use GitHub API to generate _data/github.yml"""
    # get GitHub info
    g = Github()
    repo = g.get_repo('BES-QSIG/docs')
    contributors = {}
    for ctb in repo.get_contributors():
        if ctb.name:
            name = ctb.name
        else:
            name = ctb.login
        contributors[name] = {'affiliation': ctb.company,
                              'image': ctb.avatar_url, 'email': ctb.email,
                              'github_username': ctb.login}
    # convert to yaml
    github_yml = ''
    for name in sorted(contributors.keys()):
        ctb = contributors[name]
        github_yml += part_github_yml.format(name, htmlFriendly(ctb['email']),
                                             htmlFriendly(ctb['affiliation']),
                                             htmlFriendly(ctb['image']),
                                             htmlFriendly(ctb['github_username']))
    return github_yml


def get_contributions(doc_path, input_dir):
    """Return string of top three authors and their percentage contributions"""
    # read git log
    cmd = 'git log --stat {0}'.format(doc_path)
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                               shell=True, stderr=subprocess.PIPE,
                               cwd=input_dir)
    gitlog, _ = process.communicate()
    # split into different commits
    commits = re.split('commit\s[a-zA-Z0-9]+\n', gitlog)
    # get number of changes by name
    name_changes = {}
    for commit in commits[1:]:
        # split into lines
        lines = commit.strip().split('\n')
        # search first line for author
        name_start = re.search('^Author:\s', lines[0]).end()
        name_end = re.search('^Author:\s.*\s<', lines[0]).end() - 1
        name = lines[0][name_start:name_end].strip()
        # search penultimate line for changes to file
        changes_start = re.search(doc_path + '\s\|\s', lines[-2]).end()
        changes_end = re.search(doc_path + '\s\|\s[0-9]+\s', lines[-2]).end()
        changes = float(lines[-2][changes_start:changes_end].strip())
        if name in name_changes.keys():
            name_changes[name] += changes
        else:
            name_changes[name] = changes
    # convert into rough %
    total = sum(name_changes.values())
    for name in name_changes.keys():
        name_changes[name] = round(name_changes[name]*100/total, 1)
    # sort by who made most contributions
    sorted_by_changes = sorted(name_changes.items(),
                               key=operator.itemgetter(1))
    sorted_by_changes.reverse()
    # unpack
    author_string = ''
    for e in sorted_by_changes[:2]:
        author_string += '{0} ({1}%), '.format(e[0], e[1])
    return(author_string.strip(', '))


def get_last_change(doc_path, input_dir):
    """Return string of date since last edit"""
    # read git log with formatter
    cmd = 'git log --pretty=format:"%ad" {0}'.format(doc_path)
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                               shell=True, stderr=subprocess.PIPE,
                               cwd=input_dir)
    gitlog, _ = process.communicate()
    # split into different commits
    commits = re.split('\n', gitlog)
    # take first of the list
    last_change = commits[0]
    # extract date and year (ignore time)
    last_change = last_change.split(' ')
    del last_change[3]
    return('-'.join(last_change[:4]))


def read_doc(doc_path, input_dir):
    """Return strings of front matter and doc text"""
    pattern = re.compile('\-\-\-')
    with open(os.path.join(input_dir, doc_path), 'rb') as f:
        text = f.read()
    res = pattern.search(text)
    if res:
        # there should be two ---, else this will raise an error
        text = text[res.end():]
        res = pattern.search(text)
        text_fm = text[:res.end()]
        text = text[res.end():]
        doc_fm = {}
        for e in text_fm.split('\n'):
            if ': ' in e:
                key, value = e.split(': ')
                doc_fm[key] = value.strip()
        return(doc_fm, text[1:])


def run(input_dir, output_dir):
    """Make docs in _docs_repo/ FGE friendly"""
    # get docs
    docs = [e for e in os.listdir(input_dir) if re.search('\.md', e)]
    docs = [e for e in docs if e != 'README.md']
    for doc in docs:
        # read doc
        doc_fm, doc_text = read_doc(doc, input_dir)
        # get metadata
        authors = get_contributions(doc, input_dir)
        last_change = get_last_change(doc, input_dir)
        title = doc_fm['title']
        status = doc_fm['status']
        if 'source' in doc_fm.keys():
            source = doc_fm['source']
        else:
            source = ''
        if 'source_author' in doc_fm.keys():
            source_author = doc_fm['source_author']
        else:
            source_author = ''
        permalink = '/docs/{0}/'.format(doc.replace('.md', ''))
        # construct front-matter
        new_fm = front_matter.format(authors, last_change, title, status,
                                     permalink, source, source_author)
        # combine
        new_doc = new_fm + doc_text
        # write out
        with open(os.path.join(output_dir, doc), 'wb') as f:
            f.write(new_doc)

if __name__ == '__main__':
    if os.getcwd()[-3:] != 'fge':
        sys.exit('Must only be run in fge/!')
    # sort dirs
    input_dir = os.path.join(os.getcwd(), '_docs_repo')
    if '_docs_repo' not in os.listdir(os.getcwd()):
        sys.exit('No _docs_repo/ found in cwd.')
    output_dir = os.path.join(os.getcwd(), '_docs')
    if not os.path.isdir(output_dir):
        os.mkdir(output_dir)
    # move yaml index
    data_dir = os.path.join(os.getcwd(), '_data')
    if not os.path.isdir(data_dir):
        os.mkdir(data_dir)
    docs_index_src = os.path.join(input_dir, 'index.yml')
    docs_index_d = os.path.join(data_dir, 'docs.yml')
    copyfile(docs_index_src, docs_index_d)
    # run
    run(input_dir=input_dir, output_dir=output_dir)
    # put contributors in data/contributors.yml
    github_yml = gen_github_yaml()
    with open(os.path.join(data_dir, 'github.yml'), 'wb') as f:
        f.write(github_yml)
