using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ExperimentManager : MonoBehaviour
{
    #region SINGLETON SETUP
    public static ExperimentManager Instance;
    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(this.gameObject);
        }
        else
        {
            Instance = this;
        }
    }
    #endregion

    [Header("References")]
    [SerializeField] private List<RectTransform> stimuliSpawnLocations = new List<RectTransform>();
    [SerializeField] private GameObject experimentPanel;
    [SerializeField] private GameObject menuPanel;
    [SerializeField] private GameObject stimuliPrefab;
    [SerializeField] private GameObject cuePrefab;

    private List<float> experimentParameters = new List<float>();
    private List<float> stimuliParameters = new List<float>();
    private List<GameObject> spawnedStimulus = new List<GameObject>();
    private List<GameObject> spawnedCue = new List<GameObject>();
    private Coroutine experimentCoroutine;
    private ExperimentReport report;
    private bool isExperimentRunning;

    public void SetExperimentData(List<float> parameters)
    {
        experimentParameters.Clear();
        stimuliParameters.Clear();
        for (int i = 0; i < parameters.Count; i++)
        {
            if (i < 4) stimuliParameters.Add(parameters[i]);
            else experimentParameters.Add(parameters[i]);
        }
        StartExperimentProcedure();
    }
    private void StartExperimentProcedure()
    {
        //HANDLE UI HERE
        menuPanel.SetActive(false);
        experimentPanel.SetActive(true);
        report = new ExperimentReport();
        isExperimentRunning = true;
        experimentCoroutine = StartCoroutine(ExperimentRoutine());
    }
    public IEnumerator ExperimentRoutine()
    {
        yield return new WaitForSeconds(2); //PRE-EXPERIMENT WAIT
        report.RecordExperimentStart();
        int firstSpawnIndex = 0;
        for (int i = 0; i < experimentParameters[5]; i++) //BLOCK REPEATER
        {
            report.RecordBlockStart(i);

            //CLEAR SITMULUS & CUE
            if (spawnedStimulus.Count > 0)
            {
                foreach (var stimulus in spawnedStimulus)
                {
                    Destroy(stimulus);
                }
                spawnedStimulus.Clear();
                foreach (var cue in spawnedCue)
                {
                    Destroy(cue);
                }
                spawnedCue.Clear();
            }
            //SPAWN STIMULUS & CUE
            int currentSpawnIndex = firstSpawnIndex;
            for (int j = 0; j < stimuliParameters.Count; j++)
            {
                if (currentSpawnIndex >= stimuliParameters.Count)
                {
                    GameObject stimulus = Instantiate(stimuliPrefab, stimuliSpawnLocations[currentSpawnIndex - stimuliParameters.Count]);
                    GameObject cue = Instantiate(cuePrefab, stimuliSpawnLocations[currentSpawnIndex - stimuliParameters.Count]);
                    stimulus.GetComponent<TrialBehaviour>().SetTrialParameters(stimuliParameters[j], experimentParameters[1]);
                    stimulus.SetActive(false);
                    cue.SetActive(false);
                    spawnedStimulus.Add(stimulus);
                    spawnedCue.Add(cue);
                }
                else
                {
                    GameObject stimulus = Instantiate(stimuliPrefab, stimuliSpawnLocations[currentSpawnIndex]);
                    GameObject cue = Instantiate(cuePrefab, stimuliSpawnLocations[currentSpawnIndex]);
                    stimulus.GetComponent<TrialBehaviour>().SetTrialParameters(stimuliParameters[j], experimentParameters[1]);
                    stimulus.SetActive(false);
                    cue.SetActive(false);
                    spawnedStimulus.Add(stimulus);
                    spawnedCue.Add(cue);
                }
                currentSpawnIndex++;
            }

            //TRIAL REPEATER
            for (int s = 0; s < spawnedStimulus.Count; s++)
            {
                for (int j = 0; j < experimentParameters[4]; j++)
                {
                    spawnedCue[s].SetActive(true);
                    yield return new WaitForSeconds(experimentParameters[0]); //CUE
                    spawnedCue[s].SetActive(false);

                    report.RecordStimulusStart(i, s, j, stimuliParameters[s]);
                    spawnedStimulus[s].SetActive(true);
                    yield return new WaitForSeconds(experimentParameters[1]); //STIMULUS
                    spawnedStimulus[s].SetActive(false);
                    report.RecordStimulusEnd(i, s, j, stimuliParameters[s]);

                    yield return new WaitForSeconds(experimentParameters[2]); //REST
                }
            }

            report.RecordBlockEnd(i);
            firstSpawnIndex++;
            yield return new WaitForSeconds(experimentParameters[3]); //BLOCK REST
        }

        report.RecordExperimentEnd();
        yield return new WaitForSeconds(5);
        StopExperimentProcedure(true);
    }
    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape) && isExperimentRunning)
        {
            StopExperimentProcedure(false);
        }
    }
    private void StopExperimentProcedure(bool isExperimentSuccesfullyDone)
    {
        if (!isExperimentRunning) return;
        isExperimentRunning = false;

        if (isExperimentSuccesfullyDone)
        {
            report.SaveToFile();
        }
        StopCoroutine(experimentCoroutine);
        //HANDLE UI HERE
        menuPanel.SetActive(true);
        experimentPanel.SetActive(false);
    }
}
