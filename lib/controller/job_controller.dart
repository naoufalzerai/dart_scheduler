import 'dart:async';

import 'package:lucifer/lucifer.dart';
import 'package:scheduler/service/cron_service.dart';

class JobController extends Controller {
  JobController(App app) : super(app);

  FutureOr addForm(Req req, Res res) async {
    await res.render('job/create', {});
  }

  FutureOr editForm(Req req, Res res) async {
    await res.render('job/edit',
        {'id': req.params["id"], 'job': await getJobForEdit(req.params["id"])});
  }

  FutureOr toggle(Req req, Res res) async {
    toggleJob(req.params['id']);
    await res.send('');
  }

  @override
  FutureOr index(Req req, Res res) async {
    var list = getAllJobs();
    await res.render('job/list', {
      'refresh': true,
      'data': list.entries.toList().map((e) => {'key': e.key, 'value': e.value})
    });
  }

  @override
  FutureOr create(Req req, Res res) async {
    addCron({
      'name': req.data('name'),
      'schedule': req.data('schedule'),
      'actif': req.data('enabled'),
      'script': req.data('script'),
      'params': req.data('params'),
      'app': req.data('app'),
    });
    await res.to("/job");
  }

  @override
  FutureOr edit(Req req, Res res) async {
    var data = {
      'name': req.data('name'),
      'schedule': req.data('schedule'),
      'actif': req.data('enabled'),
      'script': req.data('script'),
      'params': req.data('params'),
      'app': req.data('app'),
    };
    editCron(req.params['id'], data);
    await res.send('');
  }

  @override
  FutureOr delete(Req req, Res res) async {
    deleteJob(req.params['id']);
    await res.send('');
  }
}
