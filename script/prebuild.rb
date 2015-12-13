# Convert docs for the FGE website from the /BES-QSIG/docs repository.
# Usage:
#  ruby build.rb
#  jekyll build
# Then, upload _site/ to gh-pages branch.

# LIBS
require "FileUtils"
require 'open-uri'
require 'json'
require 'pp'

# FUNCTIONS
def mkfm(fm)
  # return doc front matter
  res = "---
layout: doc
authors: #{fm["authors"]}
lastchange: #{fm["lastchange"]}
title: #{fm["title"]}
status: #{fm["status"]}
permalink: #{fm["permalink"]}
source: #{fm["source"]}
source_author: #{fm["source_author"]}
---"
  res
end

def getYmlString(h, k)
  # Return HTML-safe hash string else "None"
  if h[k]
    res = h[k]
  else
    res = "None"
  end
  res
end

def mkgithubyml(udata)
  # Return github user yaml info
  yml = "- name: #{getYmlString(udata, "name")}
  email: #{getYmlString(udata, "email")}
  affiliation: #{getYmlString(udata, "company")}
  image: #{getYmlString(udata, "avatar_url")}
  github_username: #{getYmlString(udata, "login")}
"
  yml
end

def gen_github_yaml()
  # Return github_yml
  # Read contributors using GitHub API
  # https://gist.github.com/kyletcarlson/7911188
  url = "https://api.github.com/repos/BES-QSIG/docs/contributors"
  buffer = open(url).read
  results = JSON.parse(buffer)
  yml = ""
  puts "Working on ....\n"
  for r in results
    puts ".... [" + r['login'] + "]\n"
    buffer = open(r['url']).read
    udata = JSON.parse(buffer)
    yml += mkgithubyml(udata)
  end
  yml
end

def get_contributions(doc, path)
  #Return string of top three authors and their percentage contributions
  cmd = "cd #{path}/ && git log --stat #{doc}"
  log = `#{cmd}`
  commits = log.split(/commit\s[a-zA-Z0-9]+\n/)
  editors = {}
  for commit in commits[1..-1]
    lines = commit.strip().split(/\n/)
    name = lines[0].sub(/^Author:\s/, '')
    name = name.sub(/\s<.*/, '')
    changes = lines[-2].sub(/.*\s\|/, '')
    changes = changes.sub(/\+/, '')
    changes = changes.to_f()
    if !editors.has_key?(name)
      editors[name] = changes
    else
      editors[name] += changes
    end
  end
  total_changes = editors.values.inject(:+)
  for name in editors.keys
    percentage = editors[name]*100/total_changes
    editors[name] = percentage.round(2)
  end
  sorted = editors.sort_by { |k, v| v }
  author_string = ''
  for editor, changes in sorted.reverse
    author_string += "#{editor} (#{changes}%), "
  end
  author_string.sub(/,\s$/, "")
end

def get_last_change(doc, path)
  # Return string of date since last edit
  cmd = "cd #{path} && git log --pretty=format:'%ad' #{doc}"
  log = `#{cmd}`
  commits = log.split(/\n/)
  last_change = commits[0]
  last_change = last_change.split(/\s/)
  last_change.delete_at(3)
  last_change.delete_at(4)
  last_change.join('-')
end

def read_doc(doc, path)
  # Return strings of front matter and doc text
  text = File.read(File.join(path, doc))
  positions = text.enum_for(:scan, /\-\-\-/).map { Regexp.last_match.begin(0) }
  text_fm = text[positions[0]..positions[1]+2]
  fm = {}
  for e in text_fm.split(/\n/)
    if /: /.match(e)
      key, value = e.split(': ')
      fm[key] = value
    end
  end
  return fm, text[positions[1]+3..-1]
end

def run(input_dir, output_dir)
  # Make docs in _docs_repo/ FGE friendly"
  # get docs
  docs = Dir.entries(input_dir)
  docs.delete_if { |e| !e.include?(".md") }
  docs.delete("README.md")
  puts "Working on ....\n"
  for doc in docs
    puts ".... [" + doc + "]\n"
    fm, text = read_doc(doc, input_dir)
    fm["lastchange"] = get_last_change(doc, input_dir)
    fm["authors"] = get_contributions(doc, input_dir)
    # TODO: is this if statement needed?
    if !fm.has_key?("source")
      fm["source"] = ""
      fm["source_author"] = ""
    end
    fm["permalink"] = "/docs/#{doc.sub('.md', '')}/"
    text = mkfm(fm) + text
    File.open(File.join(output_dir, doc), 'w') { |file| file.write(text) }
  end
end

# SCRIPT
puts "Converting docs for FGE\n"
if Dir.pwd[-3..-1] != 'fge'
  puts "Halted: cwd must be fge/"
  exit
end
input_dir = File.join(Dir.pwd, "_docs_repo")
output_dir = File.join(Dir.pwd, "_docs")
if !Dir.entries(".").include?("_docs")
  Dir.mkdir("_docs")
end
data_dir = File.join(Dir.pwd, '_data')
if !Dir.entries(".").include?("_docs_repo")
  puts "Halted: no docs_repo/ found in cwd"
  exit
end
if !Dir.entries(".").include?("_data")
  Dir.mkdir("_data")
end
docs_index_src = File.join(input_dir, 'index.yml')
docs_index_d = File.join(data_dir, 'docs.yml')
FileUtils.cp(docs_index_src, docs_index_d)
run(input_dir, output_dir)
puts "Getting latest data on contributors from GitHub ....\n"
github_yml = gen_github_yaml()
File.open(File.join(data_dir, "github.yml"), 'w') { |file| file.write(github_yml) }
puts "Done\n"
