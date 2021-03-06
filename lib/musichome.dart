import 'dart:async';

import 'package:flute_music_player/flute_music_player.dart';
import 'package:flutter/material.dart';
import 'package:musicplayer/database/database_client.dart';
import 'package:musicplayer/pages/material_search.dart';
import 'package:musicplayer/pages/now_playing.dart';
import 'package:musicplayer/pages/settings.dart';
import 'package:musicplayer/util/lastplay.dart';
import 'package:musicplayer/views/album.dart';
import 'package:musicplayer/views/artists.dart';
import 'package:musicplayer/views/home.dart';
import 'package:musicplayer/views/playlists.dart';
import 'package:musicplayer/views/songs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

class MusicHome extends StatefulWidget {
  List<Song> songs;
  MusicHome();
  final bottomItems = [
    new BottomItem("Home", Icons.home),
    new BottomItem("Albums", Icons.album),
    new BottomItem("Songs", Icons.music_note),
    new BottomItem("Artists", Icons.person),
    new BottomItem("Playlists", Icons.playlist_add_check),
  ];
  @override
  State<StatefulWidget> createState() {
    return new _musicState();
  }
}

class _musicState extends State<MusicHome> {
  int _selectedDrawerIndex = 0;
  List<Song> songs;
  String title = "Music player";
  DatabaseClient db;
  bool isLoading = true;
  Song last;

  getDrawerItemWidget(int pos) {
    switch (pos) {
      case 0:
        return new Home(db);
      case 2:
        return new Songs(db);
      case 3:
        return new Artists(db);
      case 1:
        return new Album(db);
      case 4:
        return new PlayList(db);
      default:
        return new Text("Error");
    }
  }

  _onSelectItem(int index) {
    setState(() => _selectedDrawerIndex = index);
    getDrawerItemWidget(_selectedDrawerIndex);
    title = widget.bottomItems[index].title;
    // Navigator.of(context).pop(); // close the drawer
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initPlayer();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void getLast() async {
    last = await db.fetchLastSong();
    songs = await db.fetchSongs();
    setState(() {
      songs = songs;
    });
  }

  void initPlayer() async {
    db = new DatabaseClient();
    await db.create();
    if (await db.alreadyLoaded()) {
      setState(() {
        isLoading = false;
        getLast();
      });
    } else {
      var songs;
      try {
        songs = await MusicFinder.allSongs();
      } catch (e) {
        print("failed to get songs");
      }
      List<Song> list = new List.from(songs);
      for (Song song in list) db.upsertSOng(song);
      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
        getLast();
      });
    }
  }

  Future<Null> refreshData() async {
    refreshKey.currentState?.show(atTop: false);
    await Future.delayed(Duration(seconds: 2));
    setState(() {
      isLoading = true;
    });
    var db = new DatabaseClient();
    await db.insertSongs();

    setState(() {
      isLoading = false;
    });
  }

  var refreshKey = GlobalKey<RefreshIndicatorState>();
  GlobalKey<ScaffoldState> scaffoldState = new GlobalKey();
  @override
  Widget build(BuildContext context) {
    var bottomOptions = <BottomNavigationBarItem>[];
    for (var i = 0; i < widget.bottomItems.length; i++) {
      var d = widget.bottomItems[i];
      bottomOptions.add(
        new BottomNavigationBarItem(
            icon: new Icon(d.icon),
            title: new Text(d.title),
            backgroundColor: accentColor),
      );
    }
    return new WillPopScope(
      child: new Scaffold(
        key: scaffoldState,
        appBar: _selectedDrawerIndex == 0
            ? null
            : new AppBar(
                backgroundColor: accentColor,
                title: new Text(title),
                actions: <Widget>[
                  IconButton(icon: Icon(Icons.search),color: Colors.white,onPressed: null,)
                ],
              ),
        floatingActionButton: new FloatingActionButton(
            child: new Icon(Icons.play_circle_outline),
            backgroundColor: Colors.white,
            foregroundColor: accentColor,
            onPressed: () async {
              var pref = await SharedPreferences.getInstance();
              var fp = pref.getBool("played");
              print("fp=====$fp");
              if (fp == null) {
                scaffoldState.currentState.showSnackBar(
                    new SnackBar(content: Text("Play your first song.")));
              } else {
                Navigator
                    .of(context)
                    .push(new MaterialPageRoute(builder: (context) {
                  if (MyQueue.songs == null) {
                    List<Song> list = new List();
                    list.add(last);
                    MyQueue.songs = list;
                    return new NowPlaying(db, list, 0, 0);
                  } else
                    return new NowPlaying(db, MyQueue.songs, MyQueue.index, 1);
                }));
              }
            }),
        body: RefreshIndicator(
          color: accentColor,
          child: isLoading
              ? new Center(
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: new CircularProgressIndicator(),
                  ),
                )
              : getDrawerItemWidget(_selectedDrawerIndex),
          key: refreshKey,
          onRefresh: refreshData,
        ),
        bottomNavigationBar: new BottomNavigationBar(
          items: bottomOptions,
          onTap: (index) => _onSelectItem(index),
          currentIndex: _selectedDrawerIndex,
          type: BottomNavigationBarType.fixed,
          fixedColor: accentColor.withOpacity(0.7),
          iconSize: 25.0,
        ),
      ),
      onWillPop: _onWillPop,
    );
  }

  Future<bool> _onWillPop() {
    return showDialog(
          context: context,
          child: new AlertDialog(
            title: new Text('Are you sure?'),
            content: new Text('Music player will be stopped..'),
            actions: <Widget>[
              new FlatButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: new Text('No'),
              ),
              new FlatButton(
                onPressed: () {
                  MyQueue.player.stop();
                  Navigator.of(context).pop(true);
                },
                child: new Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class BottomItem {
  String title;
  IconData icon;
  BottomItem(this.title, this.icon);
}
