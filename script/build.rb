# Build docs for the FGE website from the /BES-QSIG/docs repository.
# Usage:
#  ruby build.rb
#  jekyll build
# Then, upload _site/ to gh-pages branch.

# LIBS
require "FileUtils"

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
  return res
end

def mkgithubyml(gh)
  # return github user yaml info
  yml = "- name: #{gh["name"]}
  email: #{gh["email"]}
  affiliation: #{gh["affiliation"]}
  image: #{gh["image"]}
  github_username: #{gh["github_username"]}
  "
  return yml
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
  return author_string.sub(/,\s$/, "")
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
  return last_change.join('-')
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
  return fm, text[positions[1]+2..-1]
end

def run(input_dir, output_dir)
  # Make docs in _docs_repo/ FGE friendly"
  # get docs
  docs = Dir.entries(input_dir)
  docs.delete_if { |e| !e.include?(".md") }
  docs.delete("README.md")
  for doc in docs
    puts doc
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
