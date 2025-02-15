package com.mapswithme.maps.settings;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.support.v7.app.AlertDialog;
import android.view.View;
import android.widget.ListView;

import com.mapswithme.maps.R;
import com.mapswithme.maps.base.BaseMwmListFragment;
import com.mapswithme.util.Utils;

public class StoragePathFragment extends BaseMwmListFragment implements StoragePathManager.MoveFilesListener
{
  private StoragePathManager mPathManager = new StoragePathManager();
  private StoragePathAdapter mAdapter;

  private StoragePathAdapter getAdapter()
  {
    return (StoragePathAdapter) getListView().getAdapter();
  }

  @Override
  public void onListItemClick(final ListView l, View v, final int position, long id)
  {
    getAdapter().onItemClick(position);
  }

  @Override
  public void onResume()
  {
    super.onResume();
    BroadcastReceiver receiver = new BroadcastReceiver()
    {
      @Override
      public void onReceive(Context context, Intent intent)
      {
        if (mAdapter != null)
          mAdapter.updateList(mPathManager.getStorageItems(), mPathManager.getCurrentStorageIndex(), StorageUtils.getWritableDirSize());
      }
    };
    mPathManager.startExternalStorageWatching(getActivity(), receiver, this);
    initAdapter();
    mAdapter.updateList(mPathManager.getStorageItems(), mPathManager.getCurrentStorageIndex(), StorageUtils.getWritableDirSize());
    setListAdapter(mAdapter);
  }

  @Override
  public void onPause()
  {
    super.onPause();
    mPathManager.stopExternalStorageWatching();
  }

  private void initAdapter()
  {
    if (mAdapter == null)
      mAdapter = new StoragePathAdapter(mPathManager, getActivity());
  }

  @Override
  public void moveFilesFinished(String newPath)
  {
    mAdapter.updateList(mPathManager.getStorageItems(), mPathManager.getCurrentStorageIndex(), StorageUtils.getWritableDirSize());
  }

  @Override
  public void moveFilesFailed(int errorCode)
  {
    if (!isAdded())
      return;

    final String message = "Failed to move maps with internal error :" + errorCode;
    final Activity activity = getActivity();
    new AlertDialog.Builder(activity)
        .setTitle(message)
        .setPositiveButton(R.string.report_a_bug, new DialogInterface.OnClickListener()
        {
          @Override
          public void onClick(DialogInterface dialog, int which)
          {
            Utils.sendSupportMail(activity, message);
          }
        })
        .show();
  }
}
